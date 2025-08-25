require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "react-native-outline-vpn"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => "10.0", :osx => "10.15" }
  s.source       = { :git => package["repository"], :tag => "#{s.version}" }

  s.source_files = "ios/**/*.{h,m,mm,swift}"
  s.osx.source_files = "macos/**/*.{h,m,mm,swift}"
  
  s.dependency "React-Core"
  
  # iOS specific dependencies
  s.ios.dependency "CocoaLumberjack/Swift"
  s.ios.frameworks = "NetworkExtension", "SystemConfiguration"
  
  # macOS specific dependencies  
  s.osx.dependency "CocoaLumberjack/Swift"
  s.osx.frameworks = "NetworkExtension", "SystemConfiguration", "Security"
  
  # Swift version
  s.swift_version = "5.0"
  
  # Compiler flags
  s.compiler_flags = '-DFOLLY_NO_CONFIG -DFOLLY_MOBILE=1 -DFOLLY_USE_LIBCPP=1'
  s.pod_target_xcconfig = {
    "DEFINES_MODULE" => "YES",
    "SWIFT_OBJC_INTERFACE_HEADER_NAME" => "$(SWIFT_MODULE_NAME)-Swift.h",
    # This allows the React Native library to work with both iOS and macOS
    "HEADER_SEARCH_PATHS" => "\"$(PODS_ROOT)/Headers/Private/React-Core\"",
  }

  # Vendored frameworks (we'll add Tun2socks here)
  s.ios.vendored_frameworks = "Frameworks/ios/Tun2socks.xcframework"
  s.osx.vendored_frameworks = "Frameworks/macos/Tun2socks.xcframework"
  
  # Preserve debug symbols
  s.preserve_paths = "**/*.xcframework"
  
  # Resource bundles
  s.resource_bundles = {
    'OutlineVpnResources' => ['src/**/*.js']
  }
end