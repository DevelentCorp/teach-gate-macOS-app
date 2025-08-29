# AGENTS.md

This file provides guidance to agents when working with code in this repository.

Project Architecture Rules (Non-Obvious Only)

- Build graph crosses multiple Xcode projects and frameworks; the workspace [macos/Teach Gate.xcworkspace](macos/Teach%20Gate.xcworkspace) is the integration boundary. Always design changes assuming workspace-level builds.
- React Native (JS) -> react-native-macos bundling -> App target “Teach Gate-macOS” -> Outline libs ([macos/OutlineLib/](macos/OutlineLib/), [macos/OutlineAppleLib/](macos/OutlineAppleLib/)) -> networking via [macos/Tun2socks.xcframework/](macos/Tun2socks.xcframework/).
- The RN “outline-vpn” module is intentionally not autolinked (see [react-native.config.js](react-native.config.js)); native coupling is explicit in the workspace targets. Preserve this decision when refactoring.
- CocoaPods is used for macOS in the workspace (Pods scheme present, e.g., “Pods-Teach Gate-macOS”). Maintain native deps via the workspace (Pods + Swift packages/frameworks). Prefer workspace membership over ad‑hoc linking and keep quoted paths for items with spaces.
- A single JS entrypoint [index.js](index.js) serves all platforms; platform branching should be done within code (e.g., Platform.OS) rather than per-platform entry files.
