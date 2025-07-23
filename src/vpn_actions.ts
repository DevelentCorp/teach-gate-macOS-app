import {VpnManager} from './vpn';

const vpnManager = new VpnManager();

export const connectVpn = async (tunnelId: string) => {
  await vpnManager.connect(tunnelId);
};

export const disconnectVpn = async (tunnelId: string) => {
  await vpnManager.disconnect(tunnelId);
};
