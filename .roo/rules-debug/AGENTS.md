# AGENTS.md

This file provides guidance to agents when working with code in this repository.

Project Debug Rules (Non-Obvious Only)

- Always target the workspace and exact scheme: "Teach Gate-macOS" in [macos/Teach Gate.xcworkspace](macos/Teach%20Gate.xcworkspace). Quoted paths are required because of spaces.
- To bypass local signing issues when building: add CODE_SIGNING_ALLOWED=NO to xcodebuild (macOS app runs un-signed only outside Gatekeeper; do not ship like this).
- If the JS bundle is missing at runtime, inspect the "Bundle React Native code and images" Build Phase in [macos/Teach Gate.xcodeproj/project.pbxproj](macos/Teach%20Gate.xcodeproj/project.pbxproj). It must call react-native-macos/scripts/react-native-xcode.sh with NODE_BINARY=node.
- "react-native-outline-vpn" intentionally does not appear in autolinking output because it’s disabled in [react-native.config.js](react-native.config.js). This is expected.
- Scheme enumeration for [macos/OutlineLib/OutlineLib.xcodeproj](macos/OutlineLib/OutlineLib.xcodeproj) may warn about DVT scheme load/duplicates (“VpnExtension”). You can ignore this during listing; it doesn’t necessarily indicate build failure.
- For RN unit tests, prefer name-based selection to avoid watcher/parallel edge cases: npm test -- -t "<pattern>" -i (see [**tests**/](__tests__/)).
