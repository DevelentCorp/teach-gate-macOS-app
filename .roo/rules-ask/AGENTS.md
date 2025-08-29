# AGENTS.md

This file provides guidance to agents when working with code in this repository.

Project Documentation Rules (Non-Obvious Only)

- The macOS app integrates multiple native components maintained inside this repo: [macos/OutlineLib/](macos/OutlineLib/), [macos/OutlineAppleLib/](macos/OutlineAppleLib/), Go-based components under [macos/go/outline/](macos/go/outline/), and [macos/Tun2socks.xcframework/](macos/Tun2socks.xcframework/). These are curated copies/adaptations of Outline.
- React Native UI is under [src/](src/), with a single entry [index.js](index.js). macOS uses the same entry (no [index.macos.js](index.macos.js)).
- Xcode performs bundling via the react-native-macos script (not the iOS one), as configured in [macos/Teach Gate.xcodeproj/project.pbxproj](macos/Teach%20Gate.xcodeproj/project.pbxproj).
- Use npm for scripts; there is no Yarn configuration in this repo.
