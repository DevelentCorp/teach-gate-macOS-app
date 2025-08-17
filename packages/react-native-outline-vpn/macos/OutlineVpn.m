#if __has_include("RCTBridgeModule.h")
#import "RCTBridgeModule.h"
#import "RCTEventEmitter.h"
#elif __has_include(<React/RCTBridgeModule.h>)
#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#else
#import "React/RCTBridgeModule.h"
#import "React/RCTEventEmitter.h"
#endif

@interface RCT_EXTERN_MODULE(OutlineVpn, NSObject)

RCT_EXTERN_METHOD(startVpn:(nonnull NSString *)host
                  port:(nonnull NSNumber *)port
                  password:(nonnull NSString *)password
                  method:(nonnull NSString *)method
                  prefix:(nonnull NSString *)prefix
                  providerBundleIdentifier:(nullable NSString *)providerBundleIdentifier
                  serverAddress:(nullable NSString *)serverAddress
                  tunnelId:(nullable NSString *)tunnelId
                  localizedDescription:(nullable NSString *)localizedDescription
                  successCallback:(nonnull RCTResponseSenderBlock)successCallback
                  errorCallback:(nonnull RCTResponseSenderBlock)errorCallback)

RCT_EXTERN_METHOD(disconnectVpn:(nullable id)options
                  successCallback:(nonnull RCTResponseSenderBlock)successCallback
                  errorCallback:(nonnull RCTResponseSenderBlock)errorCallback)

RCT_EXTERN_METHOD(getVpnConnectionStatus:(nonnull RCTResponseSenderBlock)callback)

@end

@interface RCT_EXTERN_MODULE(OutlineVpnBridge, RCTEventEmitter)

RCT_EXTERN_METHOD(supportedEvents)

@end