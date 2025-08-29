#import "TeachGateVPNModule.h"
#import <NetworkExtension/NetworkExtension.h>

// Import the generated OutlineTunnel Swift bridging header
@import OutlineTunnel;
#define OUTLINE_AVAILABLE 1

static NSString *const kEventVpnStatusChanged = @"vpnStatusChanged";
static NSString *const kEventVpnError = @"vpnError";
static NSString *const kDefaultTunnelId = @"TeachGateServer";
static NSString *const kDefaultDisplayName = @"Teach Gate VPN";

@interface TeachGateVPNModule ()
@property(nonatomic, assign) BOOL hasListeners;
@end

@implementation TeachGateVPNModule

RCT_EXPORT_MODULE(TeachGateVPNModule);

+ (BOOL)requiresMainQueueSetup {
  return YES; // VPN APIs are UI-sensitive
}

- (NSArray<NSString *> *)supportedEvents {
  return @[kEventVpnStatusChanged, kEventVpnError];
}

- (void)startObserving { self.hasListeners = YES; }
- (void)stopObserving { self.hasListeners = NO; }

- (instancetype)init {
  if (self = [super init]) {
#if OUTLINE_AVAILABLE
    [[OutlineVpn shared] onVpnStatusChangeObjc:^(__unused NSInteger statusValue, NSString * _Nonnull tunnelId) {
      [self emitStatusFromStatus:(NEVPNStatus)statusValue tunnelId:tunnelId];
    }];
#endif
  }
  return self;
}

#pragma mark - Exported Methods

RCT_EXPORT_METHOD(connect:(NSString *)configJson
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
#if OUTLINE_AVAILABLE
  NSString *transportYAML = [self toTransportYAML:configJson];
  if (transportYAML.length == 0) {
    if (reject) reject(@"ERR_INVALID_CONFIG", @"Configuration string is empty or invalid", nil);
    return;
  }

  NSLog(@"🔍 DEBUG: Starting VPN connection with transport config length: %lu", (unsigned long)transportYAML.length);
  
  [[OutlineVpn shared] startWithCompletion:kDefaultTunnelId
                                     named:kDefaultDisplayName
                             withTransport:transportYAML
                         completionHandler:^(NSError * _Nullable error) {
    if (error) {
      NSLog(@"🔍 DEBUG: VPN connection failed with error: %@", error);
      
      // Enhanced error handling for common VPN issues
      NSString *errorCode = [self errorCodeFromNSError:error];
      NSString *errorMessage = [self errorMessageFromNSError:error];
      
      // Check for specific VPN extension issues
      if ([errorMessage containsString:@"unexpected nil disconnect error"]) {
        NSString *detailedMessage = @"VPN Extension communication failed. This usually indicates:\n"
                                   @"• VPN Extension not properly embedded in app bundle\n"
                                   @"• Network Extension entitlements missing\n"
                                   @"• VPN permissions not granted by macOS\n"
                                   @"• Extension process failed to start\n"
                                   @"Please check Console.app for additional error details.";
        errorCode = @"ERR_EXTENSION_FAILURE";
        errorMessage = detailedMessage;
      }
      
      [self emitError:error forOperation:@"connect"];
      if (reject) reject(errorCode, errorMessage, error);
      return;
    }
    
    NSLog(@"🔍 DEBUG: VPN connection established successfully");
    if (resolve) resolve(@(YES));
  }];
#else
  NSLog(@"🔍 DEBUG: OutlineAppleLib not available - missing framework");
  if (reject) reject(@"ERR_MISSING_FRAMEWORK", @"OutlineAppleLib is not linked to the host app target", nil);
#endif
}

RCT_EXPORT_METHOD(disconnect:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
#if OUTLINE_AVAILABLE
  [[OutlineVpn shared] isActiveWithCompletion:kDefaultTunnelId completionHandler:^(__unused BOOL active) {
    // Always best-effort disconnect
    @try {
      [[OutlineVpn shared] stopWithId:kDefaultTunnelId];
    } @catch (__unused NSException *exception) {
      // Ignore "nil disconnect" crashes
    }
    if (resolve) resolve(@(YES));
  }];
#else
  if (reject) reject(@"missing_outlinelib", @"OutlineAppleLib is not linked to the host app target", nil);
#endif
}

RCT_EXPORT_METHOD(getStatus:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
#if OUTLINE_AVAILABLE
  [[OutlineVpn shared] isActiveWithCompletion:kDefaultTunnelId completionHandler:^(BOOL active) {
    if (resolve) resolve(@(active));
  }];
#else
  if (reject) reject(@"missing_outlinelib", @"OutlineAppleLib is not linked to the host app target", nil);
#endif
}

RCT_EXPORT_METHOD(toggleConnection:(NSString *)configJson
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
#if OUTLINE_AVAILABLE
  [[OutlineVpn shared] isActiveWithCompletion:kDefaultTunnelId completionHandler:^(BOOL active) {
    if (active) {
      // Safe disconnect
      [self disconnect:^(__unused id result) {
        if (resolve) resolve(@(YES));
      } rejecter:nil];
    } else {
      [self connect:configJson resolver:resolve rejecter:reject];
    }
  }];
#else
  if (reject) reject(@"missing_outlinelib", @"OutlineAppleLib is not linked to the host app target", nil);
#endif
}

#pragma mark - Helpers

- (void)emitStatusFromStatus:(NEVPNStatus)status tunnelId:(NSString *)tunnelId {
  if (!self.hasListeners) return;
  NSString *statusText = [self statusTextFromNEStatus:status];
  NSDictionary *payload = @{
    @"tunnelId": tunnelId ?: @"",
    @"status": @(status),
    @"statusText": statusText ?: @"unknown"
  };
  [self sendEventWithName:kEventVpnStatusChanged body:payload];
}

- (void)emitError:(NSError *)error forOperation:(NSString *)op {
  if (!self.hasListeners) return;
  NSString *code = [self errorCodeFromNSError:error];
  NSString *message = [self errorMessageFromNSError:error];
  NSDictionary *payload = @{
    @"operation": op ?: @"",
    @"code": code ?: @"",
    @"message": message ?: @"",
  };
  [self sendEventWithName:kEventVpnError body:payload];
}

- (NSString *)statusTextFromNEStatus:(NEVPNStatus)status {
  switch (status) {
    case NEVPNStatusInvalid: return @"invalid";
    case NEVPNStatusDisconnected: return @"disconnected";
    case NEVPNStatusConnecting: return @"connecting";
    case NEVPNStatusConnected: return @"connected";
    case NEVPNStatusReasserting: return @"reasserting";
    case NEVPNStatusDisconnecting: return @"disconnecting";
    default: return @"unknown";
  }
}

- (NSString *)toTransportYAML:(NSString *)input {
  if (input == nil) return @"";
  NSString *trimmed = [input stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if (trimmed.length == 0) return @"";
  if ([trimmed containsString:@"\ntransport:"] || [trimmed hasPrefix:@"transport:"]) {
    return trimmed;
  }
  if ([trimmed hasPrefix:@"{"] && [trimmed hasSuffix:@"}"]) {
    return [NSString stringWithFormat:@"transport: %@", trimmed];
  }
  if ([trimmed hasPrefix:@"ss://"] || [trimmed hasPrefix:@"\"ss://"] || [trimmed hasPrefix:@"'ss://"]) {
    return [NSString stringWithFormat:@"transport: %@", trimmed];
  }
  return [NSString stringWithFormat:@"transport: \"%@\"", [self yamlEscape:trimmed]];
}

- (NSString *)yamlEscape:(NSString *)s {
  NSMutableString *m = [s mutableCopy];
  [m replaceOccurrencesOfString:@"\\" withString:@"\\\\"
                         options:0 range:NSMakeRange(0, m.length)];
  [m replaceOccurrencesOfString:@"\"" withString:@"\\\""
                         options:0 range:NSMakeRange(0, m.length)];
  [m replaceOccurrencesOfString:@"\n" withString:@"\\n"
                         options:0 range:NSMakeRange(0, m.length)];
  return m;
}

- (NSString *)errorCodeFromNSError:(NSError *)error {
  NSString *code = error.userInfo[@"DetailedJsonError_ErrorCode"];
  if (code.length > 0) return code;
  return error.domain ?: @"OutlineError";
}

- (NSString *)errorMessageFromNSError:(NSError *)error {
  NSString *json = error.userInfo[@"OutlineJsonError_JsonDetails"];
  if (json.length > 0) return json;
  return error.localizedDescription ?: @"Unknown error";
}

@end
