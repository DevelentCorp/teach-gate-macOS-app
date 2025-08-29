#!/bin/zsh
set -euo pipefail
LOG="build-logs/test-header-fix.log"
mkdir -p build-logs

{
  echo "== Context =="
  date; pwd; uname -a

  echo
  echo "== Export NODE_BINARY =="
  export NODE_BINARY="$(command -v node)"
  echo "NODE_BINARY=$NODE_BINARY"

  echo
  echo "== Clean build for Teach Gate-macOS =="
  cd macos || { echo "Cannot cd macos"; exit 2; }
  rm -rf "./build"

  set -o pipefail
  xcodebuild \
    -workspace "Teach Gate.xcworkspace" \
    -scheme "Teach Gate-macOS" \
    -configuration Debug \
    -destination "generic/platform=macOS" \
    -derivedDataPath "./build" \
    CODE_SIGNING_ALLOWED=NO \
    COMPILER_INDEX_STORE_ENABLE=NO \
    ONLY_ACTIVE_ARCH=YES \
    build | tee "../$LOG"
  BUILD_EXIT=${pipestatus[1]}
  echo "xcodebuild exit code: $BUILD_EXIT"

  echo
  echo "== Build products =="
  find "./build/Build/Products/Debug" -maxdepth 4 -type d \( -name "*.app" -o -name "*.appex" \) -print 2>/dev/null || true

  echo
  echo "== Error summary =="
  grep -nE "error:|fatal error:|Undefined symbols|ld: error" "../$LOG" | tail -20 || true

  if [ $BUILD_EXIT -eq 0 ]; then
    echo
    echo "== Build SUCCESS - Attempting launch =="
    APP="./build/Build/Products/Debug/Teach Gate.app"
    if [ -d "$APP" ]; then
      echo "Launching: $APP"
      open -n "$APP" || echo "Launch failed"
      sleep 3
      pgrep -lf "Teach Gate" || echo "Process not found"
    else
      echo "App bundle not found at: $APP"
    fi
  else
    echo
    echo "== Build FAILED =="
  fi

  exit $BUILD_EXIT
} | tee "$LOG"

echo "Wrote log to: $LOG"