"use strict";

Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.default = void 0;
var _reactNative = require("react-native");
const LINKING_ERROR = `The package 'react-native-outline-vpn' doesn't seem to be linked. Make sure: \n\n` + _reactNative.Platform.select({
  ios: "- You have run 'pod install'\n",
  macos: "- You have run 'pod install'\n",
  default: ''
}) + '- You rebuilt the app after installing the package\n' + '- You are not using Expo Go\n';
const OutlineVpn = _reactNative.NativeModules.OutlineVpn ? _reactNative.NativeModules.OutlineVpn : new Proxy({}, {
  get() {
    throw new Error(LINKING_ERROR);
  }
});
const startVpn = data => {
  return new Promise(async (resolve, reject) => {
    if (_reactNative.Platform.OS === 'ios' || _reactNative.Platform.OS === 'macos') {
      try {
        await OutlineVpn.startVpn(data, successMessage => resolve(successMessage), errorMessage => reject(new Error(errorMessage)));
      } catch (error) {
        reject(error);
      }
    } else {
      // Non-Apple platforms not implemented in this package.
      resolve(false);
    }
  });
};
const getVpnConnectionStatus = () => {
  return new Promise((resolve, reject) => {
    if (_reactNative.Platform.OS === 'ios' || _reactNative.Platform.OS === 'macos') {
      OutlineVpn.getVpnConnectionStatus((error, isConnected) => {
        if (error) {
          reject(error);
        } else {
          resolve(isConnected);
        }
      });
    } else {
      // For Android or other platforms, you can return false or implement accordingly
      resolve(false);
    }
  });
};
const stopVpn = () => {
  return new Promise((resolve, reject) => {
    if (_reactNative.Platform.OS === 'ios' || _reactNative.Platform.OS === 'macos') {
      OutlineVpn.disconnectVpn(null, successResult => {
        resolve(successResult[0]);
      }, errorResult => {
        reject(new Error(errorResult[0]));
      });
    } else {
      // Android implementation
      OutlineVpn.disconnectVpn().then(result => resolve(result)).catch(error => reject(error));
    }
  });
};
var _default = exports.default = {
  startVpn(options) {
    return startVpn(options);
  },
  stopVpn() {
    return stopVpn();
  },
  getVpnStatus() {
    return getVpnConnectionStatus();
  }
};
//# sourceMappingURL=index.js.map