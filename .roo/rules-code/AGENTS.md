# AGENTS.md

This file provides guidance to agents when working with code in this repository.

Project Coding Rules (Non-Obvious Only)

- Keep a single JS entrypoint: [index.js](index.js). Do not add [index.macos.js](index.macos.js) unless you also adjust the Xcode bundling phase and app registration.
- Do not re-enable autolinking for "react-native-outline-vpn". It is intentionally disabled in [react-native.config.js](react-native.config.js); native integration lives in the workspace targets.
- When adding fonts, place files in [src/assets/fonts/](src/assets/fonts/) (the path is referenced by [react-native.config.js](react-native.config.js)). Commit the font files and rebuild; no extra JS config is needed.
- If editing Metro, retain the default merge pattern in [metro.config.js](metro.config.js) to avoid breaking the Xcode bundling phase that expects standard outputs.
- Any native macOS code or frameworks must be added to the workspace ([macos/Teach Gate.xcworkspace](macos/Teach%20Gate.xcworkspace)) — not just the standalone project — to be visible to the app target.
