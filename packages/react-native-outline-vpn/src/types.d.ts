export interface vpnOptions {
  host: string;
  port: number;
  password: string;
  method: string;
  providerBundleIdentifier?: string;
  prefix?: string;
  serverAddress?: string;
  tunnelId?: string;
  localizedDescription?: string;
}

export interface VpnModule {
  startVpn(options: vpnOptions): Promise<string | boolean>;
  stopVpn(): Promise<string>;
  getVpnStatus(): Promise<boolean>;
}

declare const vpnModule: VpnModule;
export default vpnModule;

export type startVPN = (data: vpnOptions) => Promise<string | boolean>;
export type getVpnStatus = () => Promise<boolean>;
