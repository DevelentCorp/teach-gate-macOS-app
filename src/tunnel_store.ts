interface TunnelConfig {
  id: string;
  name: string;
  address: string;
}

export class TunnelStore {
  private tunnels: Map<string, TunnelConfig> = new Map();

  add(tunnel: TunnelConfig): void {
    this.tunnels.set(tunnel.id, tunnel);
  }

  get(tunnelId: string): TunnelConfig | undefined {
    return this.tunnels.get(tunnelId);
  }

  remove(tunnelId: string): void {
    this.tunnels.delete(tunnelId);
  }
}
