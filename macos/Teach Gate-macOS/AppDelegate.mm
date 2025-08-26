#import "AppDelegate.h"

#import <React/RCTBridge.h>
#import <React/RCTBundleURLProvider.h>
#import <React/RCTRootView.h>

@interface AppDelegate ()
@property (strong, nonatomic) NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
  RCTBridge *bridge = [[RCTBridge alloc] initWithDelegate:self launchOptions:nil];
  RCTRootView *rootView = [[RCTRootView alloc] initWithBridge:bridge
                                                   moduleName:@"TeachGateDeskApp"
                                            initialProperties:@{}];

  NSRect frame = NSMakeRect(0, 0, 550, 750);
  self.window = [[NSWindow alloc] initWithContentRect:frame
                                           styleMask:NSWindowStyleMaskTitled |
                                                     NSWindowStyleMaskClosable |
                                                     NSWindowStyleMaskMiniaturizable |
                                                     NSWindowStyleMaskResizable
                                             backing:NSBackingStoreBuffered
                                               defer:NO];

  [self.window setTitle:@"Teach Gate"];
  [self.window setContentView:rootView];
  [self.window center];
  [self.window makeKeyAndOrderFront:nil];
}

- (NSURL *)sourceURLForBridge:(RCTBridge *)bridge
{
  return [self bundleURL];
}

- (NSURL *)bundleURL
{
#if DEBUG
  return [[RCTBundleURLProvider sharedSettings] jsBundleURLForBundleRoot:@"index"];
#else
  return [[NSBundle mainBundle] URLForResource:@"main" withExtension:@"jsbundle"];
#endif
}

@end
