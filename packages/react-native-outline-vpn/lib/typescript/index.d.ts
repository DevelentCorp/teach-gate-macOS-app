import { type vpnOptions } from './types';
declare const _default: {
    startVpn(options: vpnOptions): Promise<Boolean | String>;
    stopVpn(): Promise<string>;
    getVpnStatus(): Promise<boolean>;
};
export default _default;
