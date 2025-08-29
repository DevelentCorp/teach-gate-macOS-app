# AGENTS.md

This file provides guidance to agents when working with code in this repository.

Non-obvious, project-specific essentials:

- Use npm, not Yarn: [package-lock.json](package-lock.json) is present and no packageManager is set in [package.json](package.json). Yarn config is absent.
- macOS app must be built via the workspace due to multiple native libs. Paths contain spaces — always quote:
  - CLI run: npx react-native run-macos --scheme "Teach Gate-macOS" (scheme/workspace mapping comes from [react-native.config.js](react-native.config.js)).
  - Headless build (example): xcodebuild -workspace "macos/Teach Gate.xcworkspace" -scheme "Teach Gate-macOS" -destination "platform=macOS" -configuration Debug CODE_SIGNING_ALLOWED=NO build
- JS bundling is triggered by Xcode using the react-native-macos script (not the iOS one):
  - Build Phase “Bundle React Native code and images” sets NODE_BINARY=node and calls node_modules/react-native-macos/scripts/react-native-xcode.sh (declared in [macos/Teach Gate.xcodeproj/project.pbxproj](macos/Teach%20Gate.xcodeproj/project.pbxproj)).
- Single entrypoint for all platforms: [index.js](index.js). There is no [index.macos.js](index.macos.js). macOS consumes index.js.
- Autolinking override: [react-native.config.js](react-native.config.js) disables autolinking for "react-native-outline-vpn" on ios/macos/android. Do not “react-native link” this module; its native integration is managed in the Xcode workspace.
- Fonts are linked from [src/assets/fonts/](src/assets/fonts/) via [react-native.config.js](react-native.config.js). Ensure files exist there; after adding fonts, refresh the native build so the asset phase picks them up.
- Outline native pieces are workspace members (keep building via the workspace): [macos/OutlineLib/OutlineLib.xcodeproj](macos/OutlineLib/OutlineLib.xcodeproj), [macos/OutlineAppleLib/](macos/OutlineAppleLib/), and [macos/Tun2socks.xcframework/](macos/Tun2socks.xcframework/).
- Jest single test (to avoid concurrency/name matching pitfalls): npm test -- -t "<pattern>" -i (e.g., run a single describe/it by name rather than relying on file path). Tests live under [**tests**/](__tests__/).
- Prettier is non-default; match it exactly: bracketSpacing=false, bracketSameLine=true, arrowParens=avoid, trailingComma=all (see [.prettierrc.js](.prettierrc.js)).
- Harmless anomaly: scheme listing may show a duplicate “VpnExtension” in [macos/OutlineLib/OutlineLib.xcodeproj](macos/OutlineLib/OutlineLib.xcodeproj). Builds can still proceed.
