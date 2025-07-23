import {VpnService} from './vpn_service.js';
import {TunnelStore} from './tunnel_store.js';
import {VpnStatus} from './vpn_status.js';
import EventEmitter from 'events';

export class VpnManager extends EventEmitter {
  private vpnService: VpnService;
  private tunnelStore: TunnelStore;
  private status: VpnStatus = VpnStatus.DISCONNECTED;

  constructor() {
    super();
    this.vpnService = new VpnService();
    this.tunnelStore = new TunnelStore();
  }

  private setStatus(newStatus: VpnStatus) {
    if (this.status !== newStatus) {
      this.status = newStatus;
      this.emit('statusChanged', this.status);
    }
  }

  getStatus(): VpnStatus {
    return this.status;
  }

  async connect(tunnelId: string): Promise<void> {
    this.setStatus(VpnStatus.CONNECTING);
    try {
      const tunnel = this.tunnelStore.get(tunnelId);
      if (!tunnel) {
        throw new Error(`Tunnel with ID "${tunnelId}" not found`);
      }
      await this.vpnService.start(tunnel, this.setStatus.bind(this));
      this.setStatus(VpnStatus.CONNECTED);
    } catch (error) {
      console.error('Failed to connect:', error);
      this.setStatus(VpnStatus.ERROR);
      throw error;
    }
  }

  async disconnect(tunnelId: string): Promise<void> {
    this.setStatus(VpnStatus.DISCONNECTING);
    try {
      await this.vpnService.stop(tunnelId, this.setStatus.bind(this));
      this.setStatus(VpnStatus.DISCONNECTED);
    } catch (error) {
      console.error('Failed to disconnect:', error);
      this.setStatus(VpnStatus.ERROR);
      throw error;
    }
  }
}
