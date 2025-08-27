module.exports = {
  project: {
    macos: {
      scheme: 'Teach Gate-macOS',
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
