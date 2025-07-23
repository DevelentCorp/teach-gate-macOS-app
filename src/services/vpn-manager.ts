import {NativeModules} from 'react-native';

const {TeachGateVpn} = NativeModules;

export async function startVpn(accessKey: string): Promise<void> {
  return TeachGateVpn.startVpn(accessKey);
}

export async function stopVpn(): Promise<void> {
  return TeachGateVpn.stopVpn();
}
