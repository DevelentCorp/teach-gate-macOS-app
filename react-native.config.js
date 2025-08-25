module.exports = {
  project: {
    macos: {
      scheme: 'Teach Gate-macOS',
    },
  },
  // Disable autolinking for the local Outline VPN package to avoid duplicate sources with Podfile path override
  dependencies: {
    'react-native-outline-vpn': {
      platforms: {ios: null, macos: null},
    },
  },
  assets: ['./src/assets/fonts/'],
};
