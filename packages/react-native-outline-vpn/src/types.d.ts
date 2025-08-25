export interface TransportConfig {
  host: string;
  port: number;
  password: string;
  method: string;
  prefix?: string;
}

export type VPNTransport = string | TransportConfig;

export interface OnDemandRule {
  [key: string]: any;
}

export interface ConnectivityCheck {
  url?: string;
  timeoutMs?: number;
  intervalMs?: number;
  [key: string]: any;
}

/**
 * Outline-Apps style VPN configuration
 * - id: unique tunnel identifier
 * - name: localized description shown in system settings
 * - transport: JSON string or object describing transport (e.g., Shadowsocks fields)
 * - autoConnect: whether to enable on-demand connect behavior
 * - onDemandRules: platform-specific NEOnDemand rules (opaque passthrough)
 * - connectivityCheck: optional connectivity check policy (opaque passthrough)
 */
export interface vpnOptions {
  id: string;
  name?: string;
  transport: VPNTransport;
  autoConnect?: boolean;
  onDemandRules?: OnDemandRule[];
  connectivityCheck?: ConnectivityCheck;
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
