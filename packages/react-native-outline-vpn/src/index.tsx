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
  const {
    host,
    port,
    password,
    method,
    prefix = '',
    providerBundleIdentifier,
    serverAddress,
    tunnelId,
    localizedDescription,
  } = data;

  return new Promise(async (resolve, reject) => {
    if (Platform.OS === 'ios' || Platform.OS === 'macos') {
      try {
        // For macOS, pass individual parameters as expected by Swift implementation
        const result = await OutlineVpn.startVpn(
          host,
          port,
          password,
          method,
          prefix,
          providerBundleIdentifier,
          serverAddress,
          tunnelId,
          localizedDescription,
          (successMessage: string) => {
            resolve(successMessage);
          },
          (errorMessage: string) => {
            reject(new Error(errorMessage));
          },
        );
        resolve(result);
      } catch (error) {
        reject(error);
      }
    } else {
      // Android implementation
      OutlineVpn.saveCredential(host, port, password, method, prefix).then(
        (credentialResult: any) => {
          if (credentialResult) {
            OutlineVpn.getCredential().then(() => {
              OutlineVpn.prepareLocalVPN().then(() => {
                OutlineVpn.connectLocalVPN()
                  .then(() => resolve(true))
                  .catch((e: any) => reject(e));
              });
            });
          }
        },
      );
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
