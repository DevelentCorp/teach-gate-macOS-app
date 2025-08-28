#!/bin/bash
set -e

echo "== Installing/updating gomobile =="
go install golang.org/x/mobile/cmd/gomobile@latest

# Add GOPATH/bin to PATH
export PATH="$(go env GOPATH)/bin:$PATH"
gomobile init

echo "== Current Go version and GOPATH =="
go version
go env GOPATH
echo "PATH: $PATH"

echo "== Backing up current xcframework =="
cp -r "macos/Tun2socks.xcframework" "macos/Tun2socks.xcframework.backup.$(date +%s)" || true

echo "== Rebuilding Tun2socks.xcframework with gomobile bind =="
cd macos/go || { echo "Cannot cd macos/go"; exit 1; }
gomobile bind -target=ios,macos -o ../Tun2socks.xcframework \
  ./outline/platerrors \
  ./outline
cd ../..

echo "== Verifying rebuilt xcframework structure =="
find "macos/Tun2socks.xcframework" -maxdepth 4 -type f -name "*.h" -print || true
find "macos/Tun2socks.xcframework" -maxdepth 4 -type f -name "module.modulemap" -print || true

echo "== Quick check for expected symbols in headers =="
grep -r "PlaterrorsInternalError\|PlaterrorsInvalidConfig\|PlaterrorsNewPlatformError" macos/Tun2socks.xcframework || echo "Expected symbols not found - may need different Go package paths"

echo "== Running clean build to test the rebuild =="
mkdir -p build-logs
rm -rf "macos/build"
set -o pipefail
xcodebuild \
  -workspace "macos/Teach Gate.xcworkspace" \
  -scheme "Teach Gate-macOS" \
  -configuration Debug \
  -destination "generic/platform=macOS" \
  -derivedDataPath "macos/build" \
  CODE_SIGNING_ALLOWED=NO \
  COMPILER_INDEX_STORE_ENABLE=NO \
  ONLY_ACTIVE_ARCH=YES \
  build | tee "build-logs/xcodebuild-after-rebuild.log"
BUILD_EXIT=${pipestatus[1]}

echo "== Build result =="
echo "xcodebuild exit code: $BUILD_EXIT"
echo "Built products (if any):"
find "macos/build/Build/Products/Debug" -maxdepth 3 -type d -name "*.app" -print 2>/dev/null || true
find "macos/build/Build/Products/Debug" -maxdepth 4 -type d -name "*.appex" -print 2>/dev/null || true

if [ $BUILD_EXIT -eq 0 ]; then
  echo "SUCCESS: Build completed successfully!"
else
  echo "BUILD FAILED: Check build-logs/xcodebuild-after-rebuild.log for errors"
fi

exit $BUILD_EXIT