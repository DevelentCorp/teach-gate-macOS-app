// Copyright 2018 The Outline Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "PacketTunnelProvider.h"
#if __has_include("TeachGateVPN-Swift.h")
#import "TeachGateVPN-Swift.h"
#else
// Graceful fallback for indexers or partial builds where the generated Swift header
// is not available yet. Methods are typed as 'id' to avoid import-order issues.
@interface SwiftBridge : NSObject
+ (id)getTunnelNetworkSettings;
+ (id)newInvalidConfigOutlineErrorWithMessage:(NSString *)message;
+ (id)newInternalOutlineErrorWithMessage:(NSString *)message;
+ (id)newOutlineErrorFromNsError:(NSError *)error;
+ (void)saveLastErrorWithNsError:(NSError *)err;
+ (NSData *)loadLastErrorToIPCResponse;
@end
#endif

#include <arpa/inet.h>
#include <ifaddrs.h>
#include <netdb.h>

#import <Foundation/Foundation.h>
#import <NetworkExtension/NetworkExtension.h>
#import <Tun2socks/Tun2socks.h>

#if __has_include(<CocoaLumberjack/CocoaLumberjack.h>)
  #import <CocoaLumberjack/CocoaLumberjack.h>
  #if DEBUG
    static DDLogLevel ddLogLevel = DDLogLevelDebug;
  #else
    static DDLogLevel ddLogLevel = DDLogLevelInfo;
  #endif
  #define TG_DD_AVAILABLE 1
#else
  #define TG_DD_AVAILABLE 0
  // Fallback macros to NSLog when CocoaLumberjack isn't available (e.g., pods not installed yet).
  #ifndef DDLogInfo
    #define DDLogInfo(...) NSLog(__VA_ARGS__)
  #endif
  #ifndef DDLogDebug
    #define DDLogDebug(...) NSLog(__VA_ARGS__)
  #endif
  #ifndef DDLogError
    #define DDLogError(...) NSLog(__VA_ARGS__)
  #endif
  #ifndef DDLogWarn
    #define DDLogWarn(...) NSLog(__VA_ARGS__)
  #endif
#endif

// Not exposed by gobind headers in this build for Objective-C.
// Declare as a weak-import symbol so the binary links even if the symbol is absent.
FOUNDATION_EXTERN __attribute__((weak_import)) Tun2socksConnectOutlineTunnelResult*
Tun2socksConnectOutlineTunnel(id<Tun2socksTunWriter> writer, id client, BOOL isUdpSupported);

NSString *const kDefaultPathKey = @"defaultPath";

@interface PacketTunnelProvider ()<Tun2socksTunWriter>
@property (nonatomic, strong, nullable) id<Tun2socksTunnel> tunnel;
@property (nonatomic, copy, nullable) void (^startCompletion)(NSNumber *);
@property (nonatomic, copy, nullable) void (^stopCompletion)(NSNumber *);
@property (nonatomic, copy, nullable) NSString *tunnelId;
@property (nonatomic, copy, nullable) NSString *transportConfig;
@property (nonatomic, strong) dispatch_queue_t packetQueue;
@property (nonatomic, assign) BOOL isUdpSupported;
@end

@implementation PacketTunnelProvider

- (id)init {
  self = [super init];
  if (self) {
    [self setupLogging];
    // Initialize a packet queue for reading/writing packets.
    _packetQueue = dispatch_queue_create("com.teachgatedesk.develentcorp.packetqueue", DISPATCH_QUEUE_SERIAL);
  }
  return self;
}

- (void)setupLogging {
  @try {
#if TG_DD_AVAILABLE
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *containerURL = [fm containerURLForSecurityApplicationGroupIdentifier:@"group.com.teachgatedesk.develentcorp"];
    if (!containerURL) {
      // Fallback: still enable OS logger so at least we have syslog
      [DDLog addLogger:[DDOSLogger sharedInstance]];
      DDLogWarn(@"App Group container URL is nil; file logging disabled");
      return;
    }
    NSString *logsPath = [[containerURL.path stringByAppendingPathComponent:@"Logs/Extension"] stringByStandardizingPath];
    [fm createDirectoryAtPath:logsPath withIntermediateDirectories:YES attributes:nil error:nil];

    DDLogFileManagerDefault *logFileManager = [[DDLogFileManagerDefault alloc] initWithLogsDirectory:logsPath];
    DDFileLogger *fileLogger = [[DDFileLogger alloc] initWithLogFileManager:logFileManager];
    fileLogger.rollingFrequency = 60 * 60 * 24; // 24 hours
    fileLogger.maximumFileSize = 5 * 1024 * 1024; // 5 MB
    fileLogger.logFileManager.maximumNumberOfLogFiles = 7;
    fileLogger.logFileManager.logFilesDiskQuota = 30 * 1024 * 1024; // 30 MB

    [DDLog addLogger:[DDOSLogger sharedInstance]];
    [DDLog addLogger:fileLogger];

    DDLogInfo(@"CocoaLumberjack initialized for extension. Logs at %@", logsPath);
#else
    NSLog(@"CocoaLumberjack not available; using NSLog only for extension logging");
#endif
  } @catch (NSException *exception) {
    NSLog(@"Failed to setup CocoaLumberjack logging: %@", exception);
  }
}

- (void)startTunnelWithOptions:(NSDictionary *)options
            completionHandler:(void (^)(NSError *))completion {
  DDLogInfo(@"Starting tunnel");
  DDLogDebug(@"Options are %@", options);

  // mimics fetchLastDisconnectErrorWithCompletionHandler on older systems
  void (^startDone)(NSError *) = ^(NSError *err) {
    [SwiftBridge saveLastErrorWithNsError:err];
    completion(err);
  };

  // MARK: Process Config.
  if (self.protocolConfiguration == nil) {
    DDLogError(@"Failed to retrieve NETunnelProviderProtocol.");
    return startDone([SwiftBridge newInvalidConfigOutlineErrorWithMessage:@"no config specified"]);
  }
  NETunnelProviderProtocol *protocol = (NETunnelProviderProtocol *)self.protocolConfiguration;
  NSString *tunnelId = protocol.providerConfiguration[@"id"];
  if (![tunnelId isKindOfClass:[NSString class]]) {
    DDLogError(@"Failed to retrieve the tunnel id.");
    return startDone([SwiftBridge newInternalOutlineErrorWithMessage:@"no tunnel ID specified"]);
  }

  NSString *transportConfig = protocol.providerConfiguration[@"transport"];
  if (![transportConfig isKindOfClass:[NSString class]]) {
    DDLogError(@"Failed to retrieve the transport configuration.");
    return startDone([SwiftBridge newInvalidConfigOutlineErrorWithMessage:@"config is not a String"]);
  }
  self.tunnelId = tunnelId;
  self.transportConfig = transportConfig;

  // startTunnel has 3 cases:
  // - When started from the app, we get options != nil, with no ["is-on-demand"] entry.
  // - When started on-demand, we get option != nil, with ["is-on-demand"] = 1;.
  // - When started from the VPN settings, we get options == nil
  NSNumber *isOnDemandNumber = options == nil ? nil : options[@"is-on-demand"];
  bool isOnDemand = isOnDemandNumber != nil && [isOnDemandNumber intValue] == 1;
  DDLogDebug(@"isOnDemand is %d", isOnDemand);

  // Adaptation note:
  // The production Outline code performs TCP/UDP connectivity checks using additional Go-bound APIs
  // (OutlineClientConfig, OutlineCheckTCPAndUDPConnectivity, PlatformError, etc.). These are not
  // present in this project build. To integrate with the migrated tun2socks for real VPN traffic
  // while keeping scope to the PacketTunnelProvider, we bypass those pre-checks and proceed to
  // configure the system routes and start tun2socks directly.
  self.isUdpSupported = YES;

  [self startRouting:[SwiftBridge getTunnelNetworkSettings]
          completion:^(NSError *_Nullable error) {
            if (error != nil) {
              return startDone([SwiftBridge newOutlineErrorFromNsError:error]);
            }
            NSError *tun2socksError = [self startTun2Socks:self.isUdpSupported];
            if (tun2socksError != nil) {
              return startDone(tun2socksError);
            }
            [self listenForNetworkChanges];
            startDone(nil);
          }];
}

- (void)stopTunnelWithReason:(NEProviderStopReason)reason
          completionHandler:(void (^)(void))completionHandler {
  DDLogInfo(@"Stopping tunnel, reason: %ld", (long)reason);
  [self stopListeningForNetworkChanges];
  [self.tunnel disconnect];
  [self cancelTunnelWithError:nil];
  completionHandler();
}

# pragma mark - Network

- (void)startRouting:(NEPacketTunnelNetworkSettings *)settings
           completion:(void (^)(NSError *))completionHandler {
  PacketTunnelProvider * __unsafe_unretained weakSelf = self;
  [self setTunnelNetworkSettings:settings completionHandler:^(NSError * _Nullable error) {
    if (error != nil) {
      DDLogError(@"Failed to start routing: %@", error.localizedDescription);
    } else {
      DDLogInfo(@"Routing started");
      // Passing nil settings clears the tunnel network configuration. Indicate to the system that
      // the tunnel is being re-established if this is the case.
      weakSelf.reasserting = settings == nil;
    }
    completionHandler(error);
  }];
}

// Registers KVO for the `defaultPath` property to receive network connectivity changes.
- (void)listenForNetworkChanges {
  [self stopListeningForNetworkChanges];
  [self addObserver:self
         forKeyPath:kDefaultPathKey
            options:NSKeyValueObservingOptionOld
            context:nil];
}

// Unregisters KVO for `defaultPath`.
- (void)stopListeningForNetworkChanges {
  @try {
    [self removeObserver:self forKeyPath:kDefaultPathKey];
  } @catch (id exception) {
    // Observer not registered, ignore.
  }
}

- (void)observeValueForKeyPath:(nullable NSString *)keyPath
                      ofObject:(nullable id)object
                        change:(nullable NSDictionary<NSString *, id> *)change
                       context:(nullable void *)context {
  if (![kDefaultPathKey isEqualToString:keyPath]) {
    return;
  }
  // Guard against false positives by comparing the paths' string description, which includes
  // properties not exposed by the class.
  NWPath *lastPath = change[NSKeyValueChangeOldKey];
  if (lastPath == nil || [lastPath isEqualToPath:self.defaultPath] ||
      [lastPath.description isEqualToString:self.defaultPath.description]) {
    return;
  }

  dispatch_async(dispatch_get_main_queue(), ^{
    [self handleNetworkChange:self.defaultPath];
  });
}

- (void)handleNetworkChange:(NWPath *)newDefaultPath {
  DDLogInfo(@"Network connectivity changed");
  if (newDefaultPath.status == NWPathStatusSatisfied) {
    DDLogInfo(@"Reconnecting tunnel.");
    // Check whether UDP support has changed with the network, if supported by the tunnel object.
    BOOL isUdpSupported = self.tunnel ? [self.tunnel updateUDPSupport] : self.isUdpSupported;
    DDLogDebug(@"UDP support: %d -> %d", self.isUdpSupported, isUdpSupported);
    self.isUdpSupported = isUdpSupported;
    [self reconnectTunnel];
  } else {
    DDLogInfo(@"Clearing tunnel settings.");
    [self startRouting:nil completion:^(NSError * _Nullable error) {
      if (error != nil) {
        DDLogError(@"Failed to clear tunnel network settings: %@", error.localizedDescription);
      } else {
        DDLogInfo(@"Tunnel settings cleared");
      }
    }];
  }
}

/**
 Converts a struct sockaddr address |sa| to a string. Expects |maxbytes| to be allocated for |s|.
 @return whether the operation succeeded.
 */
bool getIpAddressString(const struct sockaddr *sa, char *s, socklen_t maxbytes) {
  if (!sa || !s) {
    DDLogError(@"Failed to get IP address string: invalid argument");
    return false;
  }
  switch (sa->sa_family) {
    case AF_INET:
      inet_ntop(AF_INET, &(((struct sockaddr_in *)sa)->sin_addr), s, maxbytes);
      break;
    case AF_INET6:
      inet_ntop(AF_INET6, &(((struct sockaddr_in6 *)sa)->sin6_addr), s, maxbytes);
      break;
    default:
      DDLogError(@"Cannot get IP address string: unknown address family");
      return false;
  }
  return true;
}

#pragma mark - tun2socks

/** Reconfigures routing and the UDP handler on connectivity change. */
- (void)reconnectTunnel {
  if (!self.transportConfig) {
    DDLogError(@"Failed to reconnect tunnel, missing tunnel configuration.");
    return;
  }
  [self startRouting:[SwiftBridge getTunnelNetworkSettings]
         completion:^(NSError *_Nullable error) {
           if (error != nil) {
             [self cancelTunnelWithError:error];
           }
         }];
}

- (BOOL)close:(NSError *_Nullable *)error {
  return YES;
}

- (BOOL)write:(NSData *_Nullable)packet n:(long *)n error:(NSError *_Nullable *)error {
  [self.packetFlow writePackets:@[ packet ] withProtocols:@[ @(AF_INET) ]];
  return YES;
}

// Writes packets from the VPN to the tunnel.
- (void)processPackets {
  typeof(self) __unsafe_unretained weakSelf = self;
  __block long bytesWritten = 0;
  [weakSelf.packetFlow readPacketsWithCompletionHandler:^(NSArray<NSData *> *_Nonnull packets,
                                                          NSArray<NSNumber *> *_Nonnull protocols) {
    for (NSData *packet in packets) {
      if (weakSelf.tunnel) {
        [weakSelf.tunnel write:packet ret0_:&bytesWritten error:nil];
      }
    }
    dispatch_async(weakSelf.packetQueue, ^{
      [weakSelf processPackets];
    });
  }];
}

// Starts or restarts tun2socks with the current configuration.
- (NSError*)startTun2Socks:(BOOL)isUdpSupported {
  BOOL isRestart = self.tunnel != nil && [self.tunnel isConnected];
  if (isRestart) {
    [self.tunnel disconnect];
  }
  PacketTunnelProvider * __unsafe_unretained weakSelf = self;

  // In the production Outline build, a Go Outline client object is created and passed here.
  // That API is not available in this project. Attempt to call the Go-bound symbol if available.
  if (Tun2socksConnectOutlineTunnel == NULL) {
    DDLogError(@"Tun2socksConnectOutlineTunnel symbol not found in Tun2socks.framework");
    return [SwiftBridge newInternalOutlineErrorWithMessage:@"Tun2socksConnectOutlineTunnel not available"];
  }
  Tun2socksConnectOutlineTunnelResult *result =
      Tun2socksConnectOutlineTunnel(weakSelf, nil, isUdpSupported);

  // Some gobind builds omit the 'error' property from the result. We conservatively check tunnel only.
  id<Tun2socksTunnel> tunnel = result ? result.tunnel : nil;
  if (!tunnel) {
    DDLogError(@"Failed to start tun2socks: no tunnel returned");
    return [SwiftBridge newInternalOutlineErrorWithMessage:@"tun2socks failed to return a tunnel"];
  }
  self.tunnel = tunnel;
  if (!isRestart) {
    dispatch_async(self.packetQueue, ^{
      [weakSelf processPackets];
    });
  }
  return nil;
}

#pragma mark - fetch last disconnect error

// TODO: Remove this code once we only support newer systems (macOS 13.0+, iOS 16.0+)
NSString *const kFetchLastErrorIPCName = @"fetchLastDisconnectDetailedJsonError";

- (void)handleAppMessage:(NSData *)messageData completionHandler:(void (^)(NSData * _Nullable))completion {
  // mimics fetchLastDisconnectErrorWithCompletionHandler on older systems
  NSString *ipcName = [[NSString alloc] initWithData:messageData encoding:NSUTF8StringEncoding];
  if (![ipcName isEqualToString:kFetchLastErrorIPCName]) {
    DDLogWarn(@"Invalid Extension IPC call: %@", ipcName);
    return completion(nil);
  }
  completion([SwiftBridge loadLastErrorToIPCResponse]);
}

- (void)cancelTunnelWithError:(nullable NSError *)error {
  [SwiftBridge saveLastErrorWithNsError:error];
  [super cancelTunnelWithError:error];
}

@end