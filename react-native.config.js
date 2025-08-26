module.exports = {
  project: {
    macos: {
      scheme: 'Teach Gate-macOS',
    },
  },
  // Re-enabled autolinking for local native packages so CocoaPods can pick up
  // the local podspec for react-native-outline-vpn. Previously this package
  // was disabled to avoid duplicate inclusion when the Podfile manually
  // included the pod; the Podfile no longer contains a manual pod entry.
  assets: ['./src/assets/fonts/'],
};
