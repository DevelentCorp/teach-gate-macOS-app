import {EventEmitter} from './event-emitter';
import {VpnStatus} from './types';
import {startVpn, stopVpn} from './vpn-manager';

export class VpnService extends EventEmitter {
  private status: VpnStatus = VpnStatus.DISCONNECTED;

  constructor() {
    super();
    // In a real application, you would listen for status changes from the native module
    // and update the status accordingly.
    // For this example, we'll just simulate the status changes.
  }

  private setStatus(newStatus: VpnStatus) {
    if (this.status !== newStatus) {
      this.status = newStatus;
      this.emit('statusChanged', this.status);
    }
  }

  async connect(accessKey: string): Promise<void> {
    this.setStatus(VpnStatus.CONNECTING);
    try {
      await startVpn(accessKey);
      this.setStatus(VpnStatus.CONNECTED);
    } catch (error) {
      console.error('Failed to connect:', error);
      this.setStatus(VpnStatus.ERROR);
      throw error;
    }
  }

  async disconnect(): Promise<void> {
    this.setStatus(VpnStatus.DISCONNECTING);
    try {
      await stopVpn();
      this.setStatus(VpnStatus.DISCONNECTED);
    } catch (error) {
      console.error('Failed to disconnect:', error);
      this.setStatus(VpnStatus.ERROR);
      throw error;
    }
  }

  getStatus(): VpnStatus {
    return this.status;
  }
}
