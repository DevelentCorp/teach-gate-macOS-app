module.exports = {
  project: {
    macos: {
      sourceDir: './macos', // tell RN where your macOS project lives
      project: './macos/Teach Gate.xcworkspace', // point to the right workspace
      scheme: 'Teach Gate-macOS', // your scheme
    },
  },
  // Disable autolinking for the old package so it does not get pulled into Pods
  dependencies: {
    'react-native-outline-vpn': {
      platforms: {
        ios: null,
        macos: null,
        android: null,
      },
    },
  },
  assets: ['./src/assets/fonts/'],
};
