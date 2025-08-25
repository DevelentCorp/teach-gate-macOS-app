import {NativeModules, Platform} from 'react-native';
import {type startVPN, type vpnOptions} from './types';

const LINKING_ERROR =
  `The package 'react-native-outline-vpn' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({
    ios: "- You have run 'pod install'\n",
    macos: "- You have run 'pod install'\n",
    default: '',
  }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo Go\n';

const OutlineVpn = NativeModules.OutlineVpn
  ? NativeModules.OutlineVpn
  : new Proxy(
      {},
      {
        get() {
          throw new Error(LINKING_ERROR);
        },
      },
    );

const startVpn: startVPN = (data: vpnOptions) => {
  return new Promise(async (resolve, reject) => {
    if (Platform.OS === 'ios' || Platform.OS === 'macos') {
      try {
        await OutlineVpn.startVpn(
          data,
          (successMessage: string) => resolve(successMessage),
          (errorMessage: string) => reject(new Error(errorMessage)),
        );
      } catch (error) {
        reject(error);
      }
    } else {
      // Non-Apple platforms not implemented in this package.
      resolve(false);
    }
  });
};

const getVpnConnectionStatus = (): Promise<boolean> => {
  return new Promise((resolve, reject) => {
    if (Platform.OS === 'ios' || Platform.OS === 'macos') {
      OutlineVpn.getVpnConnectionStatus((error: any, isConnected: boolean) => {
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

const stopVpn = (): Promise<string> => {
  return new Promise((resolve, reject) => {
    if (Platform.OS === 'ios' || Platform.OS === 'macos') {
      OutlineVpn.disconnectVpn(
        null,
        (successResult: any[]) => {
          resolve(successResult[0]);
        },
        (errorResult: any[]) => {
          reject(new Error(errorResult[0]));
        },
      );
    } else {
      // Android implementation
      OutlineVpn.disconnectVpn()
        .then((result: string) => resolve(result))
        .catch((error: any) => reject(error));
    }
  });
};

export default {
  startVpn(options: vpnOptions): Promise<Boolean | String> {
    return startVpn(options);
  },
  stopVpn(): Promise<string> {
    return stopVpn();
  },
  getVpnStatus(): Promise<boolean> {
    return getVpnConnectionStatus();
  },
};
