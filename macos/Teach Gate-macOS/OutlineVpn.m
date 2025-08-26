#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import <NetworkExtension/NetworkExtension.h>
#import <os/log.h>

@interface OutlineVpn : RCTEventEmitter <RCTBridgeModule>
@property (nonatomic, strong) NETunnelProviderManager *currentManager;
@end

@implementation OutlineVpn

RCT_EXPORT_MODULE();

+ (BOOL)requiresMainQueueSetup {
  return YES;
}

- (NSArray<NSString *> *)supportedEvents {
  return @[@"vpnStatusChanged"];
}

- (instancetype)init {
  self = [super init];
  if (self) {
    // Register for VPN status changes
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(vpnStatusDidChange:)
                                                 name:NEVPNStatusDidChangeNotification
                                               object:nil];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

RCT_EXPORT_METHOD(startVpn:(NSDictionary *)config
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
  
  os_log_t log = os_log_create("com.develentcorp.teachgatedesk", "OutlineVpn");
  
  dispatch_async(dispatch_get_main_queue(), ^{
    os_log_info(log, "📝 Starting VPN with config: %{public}@", config);
    
    [NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:^(NSArray<NETunnelProviderManager *> *managers, NSError *error) {
      if (error) {
        os_log_error(log, "❌ Failed to load VPN managers: %{public}@", error.localizedDescription);
        reject(@"LOAD_ERROR", @"Failed to load VPN configuration", error);
        return;
      }
      
      NETunnelProviderManager *manager = nil;
      
      // The correct bundle ID for our extension
      NSString *extensionBundleId = @"com.develentcorp.teachgatedesk.tgvpn";
      
      // Find existing manager with the correct bundle ID
      for (NETunnelProviderManager *m in managers) {
        NETunnelProviderProtocol *proto = (NETunnelProviderProtocol *)m.protocolConfiguration;
        if ([proto.providerBundleIdentifier isEqualToString:extensionBundleId]) {
          manager = m;
          os_log_info(log, "ℹ️ Found existing manager with bundle ID: %{public}@", extensionBundleId);
          break;
        }
      }
      
      // Remove any old managers with incorrect bundle IDs
      for (NETunnelProviderManager *m in managers) {
        NETunnelProviderProtocol *proto = (NETunnelProviderProtocol *)m.protocolConfiguration;
        if ([proto.providerBundleIdentifier isEqualToString:@"com.teachgatedesk.develentcorp.TeachGateVPN"] ||
            [proto.providerBundleIdentifier isEqualToString:@"com.teachgatedesk.develentcorp"]) {
          os_log_info(log, "🗑️ Removing old manager with incorrect bundle ID: %{public}@", proto.providerBundleIdentifier);
          [m removeFromPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
            if (error) {
              os_log_error(log, "Failed to remove old manager: %{public}@", error.localizedDescription);
            }
          }];
        }
      }
      
      if (!manager) {
        manager = [[NETunnelProviderManager alloc] init];
        os_log_info(log, "📝 Creating new NETunnelProviderManager");
      }
      
      // Configure the protocol
      NETunnelProviderProtocol *protocol = [[NETunnelProviderProtocol alloc] init];
      protocol.providerBundleIdentifier = extensionBundleId;
      protocol.serverAddress = config[@"serverAddress"] ?: @"TeachGateServer";
      
      // Pass the full config to the extension
      NSMutableDictionary *providerConfig = [config mutableCopy];
      providerConfig[@"id"] = config[@"tunnelId"] ?: @"TeachGateServer";
      providerConfig[@"transport"] = config[@"transport"] ?: @"{}"; // Default transport config
      protocol.providerConfiguration = providerConfig;
      
      manager.protocolConfiguration = protocol;
      manager.localizedDescription = config[@"localizedDescription"] ?: @"Teach Gate VPN";
      manager.enabled = YES;
      
      // Disable on-demand initially
      manager.onDemandRules = nil;
      
      self.currentManager = manager;
      
      os_log_info(log, "📝 Saving VPN configuration with bundle ID: %{public}@", extensionBundleId);
      
      [manager saveToPreferencesWithCompletionHandler:^(NSError *error) {
        if (error) {
          os_log_error(log, "❌ Failed to save VPN configuration: %{public}@", error.localizedDescription);
          reject(@"SAVE_ERROR", @"Failed to save VPN configuration", error);
          return;
        }
        
        os_log_info(log, "✅ VPN configuration saved successfully");
        
        // Reload preferences (workaround for iOS/macOS bug)
        [manager loadFromPreferencesWithCompletionHandler:^(NSError *error) {
          if (error) {
            os_log_error(log, "❌ Failed to reload VPN configuration: %{public}@", error.localizedDescription);
            reject(@"LOAD_ERROR", @"Failed to reload VPN configuration", error);
            return;
          }
          
          os_log_info(log, "📝 Starting VPN tunnel...");
          
          // Start the VPN tunnel
          NETunnelProviderSession *session = (NETunnelProviderSession *)manager.connection;
          
          os_log_info(log, "🔍 DIAGNOSTIC: Current VPN status before start: %{public}@", [self statusToString:session.status]);
          NSLog(@"🔍 DIAGNOSTIC: Current VPN status before start: %@", [self statusToString:session.status]);
          
          NSError *startError = nil;
          [session startTunnelWithOptions:nil andReturnError:&startError];
          
          if (startError) {
            os_log_error(log, "❌ DIAGNOSTIC: startTunnelWithOptions FAILED immediately: %{public}@", startError.localizedDescription);
            NSLog(@"🔍 DIAGNOSTIC: startTunnelWithOptions FAILED immediately: %@", startError.localizedDescription);
            reject(@"START_ERROR", @"Failed to start VPN tunnel", startError);
            return;
          }
          
          os_log_info(log, "🔍 DIAGNOSTIC: startTunnelWithOptions call SUCCESS - but this only means the START COMMAND was sent");
          NSLog(@"🔍 DIAGNOSTIC: startTunnelWithOptions call SUCCESS - but this only means the START COMMAND was sent");
          os_log_info(log, "🔍 DIAGNOSTIC: Current VPN status after start command: %{public}@", [self statusToString:session.status]);
          NSLog(@"🔍 DIAGNOSTIC: Current VPN status after start command: %@", [self statusToString:session.status]);
          
          // After successful start, enable on-demand
          dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NEOnDemandRuleConnect *connectRule = [[NEOnDemandRuleConnect alloc] init];
            connectRule.interfaceTypeMatch = NEOnDemandRuleInterfaceTypeAny;
            manager.onDemandRules = @[connectRule];
            manager.isOnDemandEnabled = YES;
            
            [manager saveToPreferencesWithCompletionHandler:^(NSError *error) {
              if (error) {
                os_log_error(log, "Failed to save on-demand rules: %{public}@", error.localizedDescription);
              } else {
                os_log_info(log, "✅ On-demand rules enabled");
              }
            }];
          });
          
          resolve(@{
            @"success": @YES,
            @"bundleId": extensionBundleId
          });
        }];
      }];
    }];
  });
}

RCT_EXPORT_METHOD(stopVpn:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
  
  os_log_t log = os_log_create("com.develentcorp.teachgatedesk", "OutlineVpn");
  
  dispatch_async(dispatch_get_main_queue(), ^{
    os_log_info(log, "📝 Stopping VPN...");
    
    [NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:^(NSArray<NETunnelProviderManager *> *managers, NSError *error) {
      if (error || managers.count == 0) {
        os_log_error(log, "❌ No VPN configuration found");
        resolve(@{@"success": @YES});
        return;
      }
      
      NETunnelProviderManager *manager = managers.firstObject;
      
      // Disable on-demand first
      manager.isOnDemandEnabled = NO;
      manager.onDemandRules = nil;
      
      [manager saveToPreferencesWithCompletionHandler:^(NSError *error) {
        if (error) {
          os_log_error(log, "Failed to disable on-demand: %{public}@", error.localizedDescription);
        }
        
        // Stop the VPN connection
        [manager.connection stopVPNTunnel];
        os_log_info(log, "✅ VPN stop command sent");
        
        resolve(@{@"success": @YES});
      }];
    }];
  });
}

RCT_EXPORT_METHOD(getVpnStatus:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
  
  dispatch_async(dispatch_get_main_queue(), ^{
    [NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:^(NSArray<NETunnelProviderManager *> *managers, NSError *error) {
      if (error || managers.count == 0) {
        resolve(@NO);
        return;
      }
      
      NETunnelProviderManager *manager = managers.firstObject;
      NEVPNStatus status = manager.connection.status;
      
      os_log_t log = os_log_create("com.develentcorp.teachgatedesk", "OutlineVpn");
      os_log_info(log, "🔍 DIAGNOSTIC: getVpnStatus - Raw status: %ld (%{public}@)", (long)status, [self statusToString:status]);
      NSLog(@"🔍 DIAGNOSTIC: getVpnStatus - Raw status: %ld (%@)", (long)status, [self statusToString:status]);
      
      // Only consider NEVPNStatusConnected as actually connected
      BOOL isConnected = (status == NEVPNStatusConnected);
      
      os_log_info(log, "🔍 DIAGNOSTIC: getVpnStatus - Returning isConnected: %{public}@", isConnected ? @"YES" : @"NO");
      NSLog(@"🔍 DIAGNOSTIC: getVpnStatus - Returning isConnected: %@", isConnected ? @"YES" : @"NO");
      
      resolve(@(isConnected));
    }];
  });
}

- (void)vpnStatusDidChange:(NSNotification *)notification {
  NEVPNConnection *connection = notification.object;
  if (connection) {
    os_log_t log = os_log_create("com.develentcorp.teachgatedesk", "OutlineVpn");
    os_log_info(log, "🔍 DIAGNOSTIC: VPN status changed to: %ld (%{public}@)", (long)connection.status, [self statusToString:connection.status]);
    NSLog(@"🔍 DIAGNOSTIC: VPN status changed to: %ld (%@)", (long)connection.status, [self statusToString:connection.status]);
    
    [self sendEventWithName:@"vpnStatusChanged"
                       body:@{
                         @"status": @(connection.status),
                         @"statusText": [self statusToString:connection.status]
                       }];
  }
}

- (NSString *)statusToString:(NEVPNStatus)status {
  switch (status) {
    case NEVPNStatusInvalid:
      return @"Invalid";
    case NEVPNStatusDisconnected:
      return @"Disconnected";
    case NEVPNStatusConnecting:
      return @"Connecting";
    case NEVPNStatusConnected:
      return @"Connected";
    case NEVPNStatusReasserting:
      return @"Reasserting";
    case NEVPNStatusDisconnecting:
      return @"Disconnecting";
    default:
      return @"Unknown";
  }
}

@end