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
  const {
    host,
    port,
    password,
    method,
    prefix,
    providerBundleIdentifier,
    serverAddress,
    tunnelId,
    localizedDescription
  } = data;
  return new Promise(async (resolve, reject) => {
    if (_reactNative.Platform.OS === 'ios' || _reactNative.Platform.OS === 'macos') {
      await OutlineVpn.startVpn(host, port, password, method, prefix, providerBundleIdentifier, serverAddress, tunnelId, localizedDescription, x => {
        resolve(x);
      }, e => {
        reject(e);
      });
    } else {
      // Android implementation
      OutlineVpn.saveCredential(host, port, password, method, prefix).then(credentialResult => {
        if (credentialResult) {
          OutlineVpn.getCredential().then(() => {
            OutlineVpn.prepareLocalVPN().then(() => {
              OutlineVpn.connectLocalVPN().then(() => resolve(true)).catch(e => reject(e));
            });
          });
        }
      });
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