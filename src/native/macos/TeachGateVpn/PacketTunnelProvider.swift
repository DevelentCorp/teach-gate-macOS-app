import NetworkExtension
import tun2socks

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    private var tunnel: Tun2socksTunnel?

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        let networkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        
        networkSettings.ipv4Settings = NEIPv4Settings(addresses: ["192.168.2.1"], subnetMasks: ["255.255.255.0"])
        networkSettings.ipv4Settings?.includedRoutes = [NEIPv4Route.default()]
        
        // This is the IP address of the DNS server that the VPN will use.
        networkSettings.dnsSettings = NEDNSSettings(servers: ["8.8.8.8"])
        
        setTunnelNetworkSettings(networkSettings) { error in
            if let error = error {
                completionHandler(error)
                return
            }
            
            // The TUN file descriptor is obtained from the `packetFlow` property.
            let tunFd = self.packetFlow.value(forKey: "socket.fileDescriptor") as! Int32
            
            // The `config` parameter from `startVpn` is passed to the tunnel provider as part of `options`.
            // We expect the config to be a JSON string with a "proxy" key.
            guard let options = options, let config = options["config"] as? String else {
                completionHandler(NSError(domain: "TeachGate", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing VPN configuration"]))
                return
            }
            
            // Start the tun2socks process.
            self.tunnel = Tun2socks.newTunnel(config, tunFileDescriptor: tunFd)
            if self.tunnel == nil {
                completionHandler(NSError(domain: "TeachGate", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create tunnel"]))
                return
            }
            
            completionHandler(nil)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        tunnel?.disconnect()
        tunnel = nil
        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Handle messages from the main app
        if let handler = completionHandler {
            handler(nil)
        }
    }
}