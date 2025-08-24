# TeachGate VPN Production Implementation Guide

**Transform from Simulation to Production-Ready VPN**

## Executive Summary

This guide provides specific, actionable steps to transform TeachGate's current VPN simulation into a production-ready implementation that exactly matches outline-apps-master's capabilities. The current implementation is operating in "test mode" with no real VPN functionality and requires complete architectural transformation.

**Critical Status**: TeachGate's VPN is currently non-functional (simulation only)
**Target**: Full production VPN matching outline-apps-master exactly
**Estimated Timeline**: 4-6 weeks
**Risk Level**: Medium-High (architectural complexity)

---

## 1. IMMEDIATE ACTION ITEMS - Critical Changes Needed Now

### 1.1 Stop Current Simulation Mode

**Current Problem**: [`PacketTunnelProvider.swift:289-305`](macos/TeachGateVPN/PacketTunnelProvider.swift:289-305) - The VPN is in pure test mode

```swift
// Current simulation code - REMOVE IMMEDIATELY
os_log("🧪 TEST MODE: Simulating successful connection for %@:%@", ...)
DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
    os_log("✅ TEST MODE: Simulated connection established", ...)
}
```

**Action**: Replace with real tun2socks integration

### 1.2 Replace Stub Go Implementation

**Current Problem**: [`packages/react-native-outline-vpn/Frameworks/macos/tun2socks-src/main.go`](packages/react-native-outline-vpn/Frameworks/macos/tun2socks-src/main.go) - 69-line stub with no VPN functionality

**Action**: Complete replacement with production Go tun2socks

### 1.3 Implement Hybrid Architecture

**Current Problem**: Pure Swift implementation instead of memory-optimized Swift/ObjC + Go hybrid

**Action**: Add Objective-C layer for memory management and Go integration

---

## 2. IMPLEMENTATION STRATEGY - 3-Phase Approach

### Phase 1: Core Foundation (Weeks 1-3) - CRITICAL

**Goal**: Replace simulation with real VPN functionality

#### Phase 1.1: Go tun2socks Integration (Week 1)

- **Priority**: CRITICAL - Blocking all VPN functionality
- **Scope**: Replace stub with production LWIP-based implementation
- **Validation**: Framework builds and imports successfully

#### Phase 1.2: Hybrid PacketTunnelProvider (Weeks 2-3)

- **Priority**: CRITICAL - Core VPN processing
- **Scope**: Swift/ObjC hybrid with memory optimization
- **Validation**: Real packet forwarding occurs

### Phase 2: Network Resilience (Week 4) - HIGH PRIORITY

**Goal**: Production-level reliability and error handling

#### Phase 2.1: Network Change Monitoring

- **Priority**: HIGH - User experience
- **Scope**: KVO-based network monitoring and auto-reconnection
- **Validation**: Automatic reconnection after network changes

#### Phase 2.2: OutlineError Framework

- **Priority**: HIGH - Debugging and support
- **Scope**: Comprehensive error handling and propagation
- **Validation**: Meaningful error messages

### Phase 3: Production Features (Weeks 5-6) - MEDIUM PRIORITY

**Goal**: Feature completeness and optimization

#### Phase 3.1: Advanced VPN Management

- **Priority**: MEDIUM - Feature completeness
- **Scope**: On-demand rules, auto-connect, session persistence
- **Validation**: All advanced features function correctly

#### Phase 3.2: Performance Optimization

- **Priority**: MEDIUM - Performance
- **Scope**: Memory optimization, enhanced logging
- **Validation**: Memory usage < 15MB, performance benchmarks met

---

## 3. FILE MIGRATION PLAN - Exact File Mappings

### 3.1 Copy Exactly (No Modifications Required)

#### **Core Go Implementation**

```bash
# Source: outline-apps-master repository
FROM: client/go/outline/tun2socks/
TO: packages/react-native-outline-vpn/Frameworks/macos/tun2socks-src/

FILES TO COPY:
✅ tunnel.go (156 lines) → tunnel.go
✅ tunnel_darwin.go (66 lines) → tunnel_darwin.go
✅ tcp.go → tcp.go
✅ udp.go → udp.go
✅ go.mod → go.mod
✅ go.sum → go.sum
```

#### **Hybrid PacketTunnelProvider Core**

```bash
FROM: client/src/cordova/apple/OutlineLib/VpnExtension/Sources/
TO: macos/TeachGateVPN/

FILES TO COPY:
✅ PacketTunnelProvider.m (336 lines) → PacketTunnelProvider.m
✅ PacketTunnelProvider.h (46 lines) → PacketTunnelProvider.h
✅ VpnExtension-Bridging-Header.h → VpnExtension-Bridging-Header.h
```

#### **Error Handling Framework**

```bash
FROM: client/src/cordova/apple/OutlineAppleLib/Sources/OutlineError/
TO: packages/react-native-outline-vpn/OutlineError/

FILES TO COPY:
✅ All OutlineError Swift package files
✅ Error definitions and propagation mechanisms
```

### 3.2 Adapt for TeachGate (Modifications Required)

#### **App-Level VPN Management**

```bash
SOURCE: client/src/cordova/apple/OutlineAppleLib/Sources/OutlineTunnel/OutlineVpn.swift
TARGET: packages/react-native-outline-vpn/macos/OutlineVpn.swift

MODIFICATIONS REQUIRED:
🔄 Replace Cordova callbacks with React Native bridge methods
🔄 Update bundle identifiers: com.teachgatedesk.develentcorp.*
🔄 Change app group: group.com.teachgatedesk.develentcorp
🔄 Adapt configuration format
```

#### **PacketTunnelProvider Helper Functions**

```bash
SOURCE: client/src/cordova/apple/OutlineLib/VpnExtension/Sources/PacketTunnelProvider.swift
TARGET: macos/TeachGateVPN/PacketTunnelProvider.swift

MODIFICATIONS REQUIRED:
🔄 Adapt helper functions for TeachGate configuration
🔄 Update logging subsystem names
🔄 Integrate with TeachGate's error reporting
```

### 3.3 Build Configuration Changes

#### **Xcode Project Updates**

```bash
TARGET: macos/Teach Gate.xcodeproj/project.pbxproj

CHANGES REQUIRED:
🔄 Add Objective-C compilation flags
🔄 Link Tun2socks.framework
🔄 Add OutlineError dependency
🔄 Configure bridging headers
🔄 Update build settings for hybrid Swift/ObjC
```

---

## 4. DEPENDENCIES AND SETUP - Required Tools and Frameworks

### 4.1 Development Environment Requirements

#### **Go Development Setup**

```bash
# Required Go version
go version >= 1.19

# Install gomobile for iOS/macOS bindings
go install golang.org/x/mobile/cmd/gomobile@latest
gomobile init

# Build dependencies
brew install protobuf
```

#### **Xcode Configuration**

```bash
# Required Xcode version
Xcode >= 14.0

# Required macOS deployment target
MACOSX_DEPLOYMENT_TARGET = 11.0

# Required Swift version
SWIFT_VERSION = 5.0

# Enable Objective-C bridging
ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES = YES
```

### 4.2 Framework Dependencies

#### **CocoaPods Updates**

```ruby
# Add to Podfile
target 'TeachGateVPN' do
  pod 'CocoaLumberjack', '~> 3.7'
  pod 'OutlineError', :path => '../packages/react-native-outline-vpn/OutlineError'
end

target 'Teach Gate-macOS' do
  pod 'CocoaLumberjack', '~> 3.7'
end
```

#### **Go Module Configuration**

```go
// packages/react-native-outline-vpn/Frameworks/macos/tun2socks-src/go.mod
module github.com/teachgate/tun2socks

go 1.19

require (
    github.com/Jigsaw-Code/outline-go-tun2socks v1.0.0
    github.com/shadowsocks/go-shadowsocks2 v0.1.5
)
```

### 4.3 Build Script Requirements

#### **Framework Build Script**

```bash
#!/bin/bash
# build-tun2socks-framework.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/../../../.."
TUNTOSOCKS_ROOT="$PROJECT_ROOT/packages/react-native-outline-vpn/Frameworks/macos/tun2socks-src"
FRAMEWORK_PATH="$PROJECT_ROOT/packages/react-native-outline-vpn/Frameworks/macos/Tun2socks.framework"

echo "Building tun2socks framework..."
cd "$TUNTOSOCKS_ROOT"

# Build for macOS
gomobile bind -target=macos -o "$FRAMEWORK_PATH" .

echo "Framework built successfully at: $FRAMEWORK_PATH"
```

---

## 5. TESTING AND VALIDATION - Verification Framework

### 5.1 Phase 1 Validation Criteria

#### **Go Framework Integration Test**

```bash
# Test 1: Framework builds successfully
./build-tun2socks-framework.sh
if [ -f "packages/react-native-outline-vpn/Frameworks/macos/Tun2socks.framework/Tun2socks" ]; then
    echo "✅ Go framework built successfully"
else
    echo "❌ Framework build failed"
    exit 1
fi

# Test 2: Framework can be imported in Swift
# Add to PacketTunnelProvider.swift:
@import Tun2socks
```

#### **Real VPN Connection Test**

```swift
// Validation: No more simulation mode
// REMOVE: All "TEST MODE" logging
// VERIFY: Real packet forwarding occurs

func validateRealConnection() {
    // Check that packets are actually processed through tun2socks
    let result = Tun2socksConnectOutlineTunnel(self, config, isUdpSupported)
    assert(result.error == nil, "Real VPN connection must succeed")
}
```

### 5.2 Phase 2 Validation Criteria

#### **Network Resilience Test**

```swift
// Test: Network change detection
func testNetworkChange() {
    // Simulate network interface change
    // Verify automatic reconnection occurs
    // Check that connection status is properly updated
}

// Test: Error propagation
func testErrorHandling() {
    // Trigger various error conditions
    // Verify OutlineError framework provides meaningful messages
    // Check error reporting to main app
}
```

#### **Memory Usage Validation**

```bash
# Monitor VPN extension memory usage
# Must stay under 15MB limit
instruments -t "Allocations" -D trace.trace TeachGate-macOS.app
```

### 5.3 Phase 3 Validation Criteria

#### **Feature Completeness Test**

```swift
// Test: On-demand VPN rules
func testOnDemandRules() {
    // Verify VPN connects automatically when needed
    // Check rules are properly configured
}

// Test: Auto-connect functionality
func testAutoConnect() {
    // Verify VPN connects on boot
    // Check network change triggers reconnection
}
```

#### **Performance Benchmarks**

```bash
# Connection establishment time
target: < 10 seconds

# Packet processing latency
target: < 50ms

# Reconnection time after network change
target: < 5 seconds

# Memory usage
target: < 15MB (VPN extension limit)
```

---

## 6. RISK ASSESSMENT - Potential Issues and Mitigation

### 6.1 High-Risk Areas

#### **Risk 1: Go Framework Integration Complexity**

**Problem**: Complex gomobile build process, platform-specific compilation issues
**Impact**: Could block Phase 1 completely
**Mitigation Strategies**:

- Set up dedicated Go build environment
- Create automated build scripts with error handling
- Test framework integration independently before main implementation
- Have fallback plan to use pre-built frameworks if compilation fails

**Fallback Strategy**:

```bash
# If gomobile build fails, use pre-compiled framework
# Download from outline-apps-master releases
curl -L -o Tun2socks.framework.zip "https://github.com/Jigsaw-Code/outline-apps/releases/latest/download/tun2socks-macos.zip"
```

#### **Risk 2: Memory Constraint Violations**

**Problem**: macOS VPN extensions have 15MB memory limit
**Impact**: Extension termination, VPN disconnection
**Mitigation Strategies**:

- Implement memory monitoring in development
- Copy exact memory optimization patterns from outline-apps-master
- Use hybrid Swift/ObjC architecture for better memory management
- Implement proper resource cleanup

**Memory Monitoring Code**:

```swift
func monitorMemoryUsage() {
    let info = mach_task_basic_info()
    let memoryUsage = info.resident_size / 1024 / 1024 // MB
    if memoryUsage > 12 { // Warn at 80% of limit
        os_log("⚠️ Memory usage high: %d MB", log: logger, type: .error, memoryUsage)
    }
}
```

### 6.2 Medium-Risk Areas

#### **Risk 3: NetworkExtension API Compatibility**

**Problem**: macOS-specific API differences from iOS implementation
**Impact**: Network configuration failures, connection issues
**Mitigation**:

- Test on multiple macOS versions
- Follow Apple's NetworkExtension best practices exactly
- Copy working patterns from outline-apps-master

#### **Risk 4: Existing App Compatibility**

**Problem**: Breaking changes to current React Native bridge API
**Impact**: App crashes, configuration failures
**Mitigation**:

- Maintain backward compatibility in bridge methods
- Gradual API migration with deprecation warnings
- Comprehensive testing of React Native integration

### 6.3 Low-Risk Areas

#### **Risk 5: Build Configuration Complexity**

**Problem**: Xcode project configuration with multiple languages
**Mitigation**: Follow exact patterns from outline-apps-master project configuration

---

## 7. TIMELINE ESTIMATES - Detailed Implementation Schedule

### Week 1: Go tun2socks Integration

```
Day 1-2: Environment Setup
- Install Go development tools
- Set up gomobile build environment
- Create build scripts

Day 3-4: Core Go Implementation
- Copy production tun2socks files
- Adapt package imports and configuration
- Build initial framework

Day 5: Integration Testing
- Test framework builds successfully
- Verify imports in Swift
- Basic connectivity testing
```

### Week 2: Hybrid PacketTunnelProvider - Part 1

```
Day 1-2: Objective-C Integration
- Copy PacketTunnelProvider.m and .h
- Set up Objective-C bridging
- Configure Xcode build settings

Day 3-4: Swift Helper Functions
- Adapt PacketTunnelProvider.swift helpers
- Integrate with Go tun2socks calls
- Update configuration handling

Day 5: Basic Functionality Testing
- Test real VPN connection establishment
- Verify packet processing begins
- Check memory usage
```

### Week 3: Hybrid PacketTunnelProvider - Part 2

```
Day 1-2: Error Handling Integration
- Copy OutlineError framework
- Integrate error propagation
- Update all error handling paths

Day 3-4: Network Settings Optimization
- Copy network configuration patterns
- Implement subnet selection logic
- Add proper DNS configuration

Day 5: Phase 1 Validation
- Complete functional testing
- Verify no simulation mode remains
- Performance baseline testing
```

### Week 4: Network Resilience

```
Day 1-2: Network Change Monitoring
- Implement KVO-based monitoring
- Add automatic reconnection logic
- Test network interface changes

Day 3-4: Advanced VPN Management
- Upgrade OutlineVpn.swift
- Add session persistence
- Implement connectivity checking

Day 5: Phase 2 Validation
- Test network resilience features
- Validate error handling
- Memory usage verification
```

### Week 5: Advanced Features

```
Day 1-2: On-Demand VPN Rules
- Copy on-demand configuration
- Implement auto-connect logic
- Test rule-based connections

Day 3-4: Enhanced Logging
- Replace os.log with CocoaLumberjack
- Add file-based logging
- Configure log rotation

Day 5: Feature Testing
- Test all advanced features
- Validate logging functionality
- Performance optimization
```

### Week 6: Final Integration and Testing

```
Day 1-2: React Native Bridge Updates
- Update bridge methods for new features
- Test React Native integration
- Fix any compatibility issues

Day 3-4: Comprehensive Testing
- End-to-end functionality testing
- Performance benchmark validation
- Security and stability testing

Day 5: Production Readiness
- Final code review
- Documentation updates
- Release preparation
```

---

## 8. SUCCESS CRITERIA - Measurable Objectives

### 8.1 Functional Requirements (Must Have)

#### **Core VPN Functionality**

- ✅ **Real VPN tunneling**: No simulation mode, actual packet forwarding
- ✅ **Shadowsocks connection**: Successful connection to real Shadowsocks servers
- ✅ **Bidirectional traffic**: Both upload and download through VPN tunnel
- ✅ **DNS resolution**: DNS queries routed through VPN tunnel
- ✅ **Traffic routing**: All internet traffic routed through VPN

**Validation Test**:

```bash
# Verify real VPN functionality
curl -s https://ifconfig.me  # Should show VPN server IP
nslookup google.com          # Should use VPN DNS servers
```

#### **Network Resilience**

- ✅ **Auto-reconnection**: Automatic reconnection after network changes
- ✅ **Network monitoring**: KVO-based network path monitoring
- ✅ **Connection recovery**: Recovery from temporary network interruptions
- ✅ **UDP fallback**: Automatic fallback when UDP is blocked

### 8.2 Performance Requirements (Must Meet)

#### **Memory and Performance**

- ✅ **Memory limit**: VPN extension usage < 15MB at all times
- ✅ **Connection time**: VPN connection establishment < 10 seconds
- ✅ **Latency**: Packet processing latency < 50ms
- ✅ **Reconnection time**: Network change recovery < 5 seconds

**Performance Monitoring**:

```swift
// Memory usage check
let memoryUsage = ProcessInfo.processInfo.physicalMemory / 1024 / 1024
assert(memoryUsage < 15, "Memory usage must be under 15MB")

// Connection timing
let startTime = Date()
// ... establish connection
let connectionTime = Date().timeIntervalSince(startTime)
assert(connectionTime < 10.0, "Connection must establish within 10 seconds")
```

### 8.3 Reliability Requirements (Must Achieve)

#### **Stability and Error Handling**

- ✅ **Uptime**: 99.9% uptime during stable network conditions
- ✅ **Error handling**: All error conditions handled gracefully
- ✅ **Logging**: Comprehensive logging for debugging
- ✅ **Recovery**: Automatic recovery from all recoverable errors

#### **Feature Completeness**

- ✅ **React Native integration**: Full React Native bridge compatibility
- ✅ **Configuration management**: Complete VPN configuration handling
- ✅ **Status reporting**: Accurate VPN status reporting to main app
- ✅ **Advanced features**: On-demand rules, auto-connect functionality

---

## 9. IMPLEMENTATION COMMANDS - Exact Commands to Execute

### 9.1 Environment Setup Commands

```bash
# Set up Go development environment
brew install go protobuf
go version  # Verify >= 1.19

# Install gomobile
go install golang.org/x/mobile/cmd/gomobile@latest
gomobile init

# Navigate to project root
cd /Users/obedsayyad/teach-gate-macOS-app

# Create backup of current implementation
cp -r macos/TeachGateVPN macos/TeachGateVPN.backup
cp -r packages/react-native-outline-vpn packages/react-native-outline-vpn.backup
```

### 9.2 Phase 1 Implementation Commands

#### **Step 1: Download outline-apps-master**

```bash
# Clone outline-apps-master for reference
git clone https://github.com/Jigsaw-Code/outline-apps.git ../outline-apps-master
cd ../outline-apps-master
git checkout main  # Use latest stable version
cd ../teach-gate-macOS-app
```

#### **Step 2: Replace Go tun2socks Implementation**

```bash
# Remove existing stub implementation
rm -rf packages/react-native-outline-vpn/Frameworks/macos/tun2socks-src/*

# Copy production Go implementation
cp ../outline-apps-master/client/go/outline/tun2socks/*.go \
   packages/react-native-outline-vpn/Frameworks/macos/tun2socks-src/

cp ../outline-apps-master/client/go/outline/tun2socks/go.mod \
   packages/react-native-outline-vpn/Frameworks/macos/tun2socks-src/

cp ../outline-apps-master/client/go/outline/tun2socks/go.sum \
   packages/react-native-outline-vpn/Frameworks/macos/tun2socks-src/

# Update module name in go.mod
cd packages/react-native-outline-vpn/Frameworks/macos/tun2socks-src
sed -i '' 's|module .*|module github.com/teachgate/tun2socks|' go.mod
cd ../../../../..
```

#### **Step 3: Build Go Framework**

```bash
# Create build script
cat > build-tun2socks-framework.sh << 'EOF'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
TUNTOSOCKS_ROOT="$SCRIPT_DIR/packages/react-native-outline-vpn/Frameworks/macos/tun2socks-src"
FRAMEWORK_PATH="$SCRIPT_DIR/packages/react-native-outline-vpn/Frameworks/macos/Tun2socks.framework"

echo "Building tun2socks framework..."
cd "$TUNTOSOCKS_ROOT"

# Download dependencies
go mod tidy

# Build for macOS
gomobile bind -target=macos -o "$FRAMEWORK_PATH" .

echo "✅ Framework built successfully at: $FRAMEWORK_PATH"
EOF

chmod +x build-tun2socks-framework.sh

# Build the framework
./build-tun2socks-framework.sh
```

#### **Step 4: Add Objective-C PacketTunnelProvider**

```bash
# Copy Objective-C implementation
cp ../outline-apps-master/client/src/cordova/apple/OutlineLib/VpnExtension/Sources/PacketTunnelProvider.m \
   macos/TeachGateVPN/

cp ../outline-apps-master/client/src/cordova/apple/OutlineLib/VpnExtension/Sources/PacketTunnelProvider.h \
   macos/TeachGateVPN/

# Create bridging header
cat > macos/TeachGateVPN/VpnExtension-Bridging-Header.h << 'EOF'
//
//  VpnExtension-Bridging-Header.h
//  TeachGateVPN
//

#import "PacketTunnelProvider.h"
@import Tun2socks;
EOF

# Update bundle identifiers in PacketTunnelProvider.m
sed -i '' 's/com\.getoutline\.macos/com.teachgatedesk.develentcorp/g' macos/TeachGateVPN/PacketTunnelProvider.m
sed -i '' 's/group\.com\.getoutline\.macos/group.com.teachgatedesk.develentcorp/g' macos/TeachGateVPN/PacketTunnelProvider.m
```

### 9.3 Phase 2 Implementation Commands

#### **Step 5: Copy OutlineError Framework**

```bash
# Copy error handling framework
mkdir -p packages/react-native-outline-vpn/OutlineError
cp -r ../outline-apps-master/client/src/cordova/apple/OutlineAppleLib/Sources/OutlineError/* \
      packages/react-native-outline-vpn/OutlineError/
```

#### **Step 6: Update OutlineVpn.swift**

```bash
# Back up current OutlineVpn.swift
cp packages/react-native-outline-vpn/macos/OutlineVpn.swift \
   packages/react-native-outline-vpn/macos/OutlineVpn.swift.backup

# Copy advanced OutlineVpn.swift and adapt for React Native
cp ../outline-apps-master/client/src/cordova/apple/OutlineAppleLib/Sources/OutlineTunnel/OutlineVpn.swift \
   packages/react-native-outline-vpn/macos/OutlineVpn.swift.new

# Manual adaptation required for React Native bridge methods
echo "⚠️  Manual adaptation required for OutlineVpn.swift React Native integration"
```

### 9.4 Phase 3 Implementation Commands

#### **Step 7: Update CocoaPods Dependencies**

```bash
# Add CocoaLumberjack to Podfile
echo "
target 'TeachGateVPN' do
  pod 'CocoaLumberjack', '~> 3.7'
end

target 'Teach Gate-macOS' do
  pod 'CocoaLumberjack', '~> 3.7'
end
" >> macos/Podfile

# Install dependencies
cd macos
pod install
cd ..
```

#### **Step 8: Update Xcode Project Configuration**

```bash
# These changes require manual Xcode configuration:
echo "⚠️  Manual Xcode project updates required:"
echo "1. Add PacketTunnelProvider.m and .h to TeachGateVPN target"
echo "2. Set Objective-C Bridging Header: VpnExtension-Bridging-Header.h"
echo "3. Link Tun2socks.framework to TeachGateVPN target"
echo "4. Add OutlineError dependency to both targets"
echo "5. Enable 'Always Embed Swift Standard Libraries'"
```

### 9.5 Testing Commands

```bash
# Build and test the project
cd macos
xcodebuild -workspace "Teach Gate.xcworkspace" -scheme "Teach Gate-macOS" -configuration Debug build

# Run memory usage test
instruments -t "Allocations" -D memory-trace.trace "Teach Gate-macOS.app" &

# Test VPN functionality
echo "Manual testing required:"
echo "1. Install and run the app"
echo "2. Configure a real Shadowsocks server"
echo "3. Connect to VPN and verify real IP change"
echo "4. Test network change resilience"
echo "5. Monitor memory usage stays under 15MB"
```

---

## 10. FALLBACK STRATEGIES - If Issues Arise

### 10.1 Go Framework Build Failures

**If gomobile build fails:**

```bash
# Fallback 1: Use pre-built framework from outline-apps-master releases
curl -L -o tun2socks-macos.zip "https://github.com/Jigsaw-Code/outline-apps/releases/latest/download/tun2socks-macos.zip"
unzip tun2socks-macos.zip
cp -r Tun2socks.framework packages/react-native-outline-vpn/Frameworks/macos/

# Fallback 2: Use Docker for consistent build environment
docker run --rm -v $(pwd):/workspace golang:1.19 /bin/bash -c \
  "cd /workspace/packages/react-native-outline-vpn/Frameworks/macos/tun2socks-src && \
   go install golang.org/x/mobile/cmd/gomobile@latest && \
   gomobile init && \
   gomobile bind -target=macos -o ../Tun2socks.framework ."
```

### 10.2 Memory Limit Violations

**If extension exceeds 15MB:**

```bash
# Revert to previous checkpoint
cp -r macos/TeachGateVPN.backup macos/TeachGateVPN
cp -r packages/react-native-outline-vpn.backup packages/react-native-outline-vpn

# Apply only critical components
echo "Apply minimal implementation:"
echo "1. Focus only on Core Go integration"
echo "2. Skip advanced features temporarily"
echo "3. Implement memory monitoring first"
```

### 10.3 React Native Bridge Compatibility Issues

**If bridge methods break:**

```swift
// Maintain backward compatibility wrapper
@objc
func startVpnLegacy(_ host: String, /* ... other parameters ... */) {
    // Call new implementation but maintain old signature
    startVpnNew(host, /* adapted parameters */)
}
```

---

## CONCLUSION

This implementation guide provides the exact steps needed to transform TeachGate's VPN from simulation mode to production-ready functionality that matches outline-apps-master exactly. The phased approach minimizes risk while ensuring each component is properly validated before moving to the next phase.

**Critical Success Factors:**

1. **Complete Go tun2socks integration** - This is the foundation of real VPN functionality
2. **Hybrid Swift/ObjC architecture** - Required for memory optimization and performance
3. **Comprehensive testing at each phase** - Prevents cascading failures
4. **Memory monitoring throughout development** - Critical for avoiding 15MB limit violations

**Timeline Summary:**

- **Weeks 1-3**: Core functionality implementation
- **Week 4**: Network resilience and reliability
- **Weeks 5-6**: Advanced features and optimization
- **Total**: 4-6 weeks depending on complexity

**Next Steps:**

1. Set up development environment with Go and gomobile
2. Begin Phase 1 with Go tun2socks integration
3. Validate each step before proceeding to next phase
4. Maintain regular backups throughout implementation

The key to success is following the proven patterns from outline-apps-master exactly while adapting only the necessary configuration elements for TeachGate's specific requirements.
