export enum VpnStatus {
  CONNECTED = 'CONNECTED',
  DISCONNECTED = 'DISCONNECTED',
  CONNECTING = 'CONNECTING',
  DISCONNECTING = 'DISCONNECTING',
  ERROR = 'ERROR',
}

export interface VpnError {
  message: string;
  code?: string;
}
