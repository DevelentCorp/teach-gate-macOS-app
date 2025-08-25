source 'https://rubygems.org'

# You may use http://rbenv.org/ or https://rvm.io/ to install and use this version
ruby ">= 2.6.10"

# Exclude problematic versions of cocoapods and activesupport that causes build failures.
# Pin CocoaPods to 1.16.2 to match Podfile.lock and avoid FrozenError on Ruby 2.6 error reporter
gem 'cocoapods', '1.16.2'
gem 'activesupport', '>= 6.1.7.5', '!= 7.1.0'
# Allow newer xcodeproj to support Xcode 16's PBXFileSystemSynchronizedRootGroup
gem 'xcodeproj', '>= 1.26.0'
gem 'concurrent-ruby', '< 1.3.4'
