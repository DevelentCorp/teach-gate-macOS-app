//
//  PacketTunnelProvider.swift
//  TeachGateVPN
//
//  Created by TeachGate VPN Extension
//

import NetworkExtension
import os.log

// Import Tun2socks framework when available
#if canImport(Tun2socks)
import Tun2socks
#endif

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    private let logger = OSLog(subsystem: "com.teachgatedesk.develentcorp.TeachGateVPN", category: "PacketTunnelProvider")
    private let appGroup = "group.com.teachgatedesk.develentcorp"
    
    #if canImport(Tun2socks)
    private var tunnel: Tun2socksTunnel?
    private var shadowsocksClient: ShadowsocksClient?
    #else
    private var tunnel: Any?
    private var shadowsocksClient: Any?
    #endif
    
    private var vpnConfig: [String: Any] = [:]

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        os_log("📱 Network Extension: Starting tunnel with options: %@", log: logger, type: .info, String(describing: options))
        
        // Extract VPN configuration
        extractVpnConfiguration()
        
        // Validate configuration
        guard let host = vpnConfig["host"] as? String,
              let port = vpnConfig["port"] as? NSNumber,
              let password = vpnConfig["password"] as? String,
              let method = vpnConfig["method"] as? String,
              !host.isEmpty, !password.isEmpty else {
            os_log("❌ Invalid VPN configuration in startTunnel", log: logger, type: .error)
            let error = NSError(domain: "TeachGateVPN", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid VPN configuration"])
            completionHandler(error)
            return
        }
        
        os_log("✅ VPN config validated - Host: %@, Port: %@, Method: %@", log: logger, type: .info, host, port, method)
        
        // Configure network settings
        let networkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: host)
        
        // IPv4 settings
        let ipv4Settings = NEIPv4Settings(addresses: ["172.16.1.1"], subnetMasks: ["255.255.255.255"])
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        networkSettings.ipv4Settings = ipv4Settings
        
        // DNS settings - Use reliable DNS servers
        let dnsSettings = NEDNSSettings(servers: ["1.1.1.1", "1.0.0.1"])
        networkSettings.dnsSettings = dnsSettings
        
        os_log("🌐 Setting tunnel network settings...", log: logger, type: .info)
        
        // Apply network settings
        setTunnelNetworkSettings(networkSettings) { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                os_log("❌ Failed to set network settings: %@", log: self.logger, type: .error, error.localizedDescription)
                completionHandler(error)
                return
            }
            
            os_log("✅ Network settings applied successfully", log: self.logger, type: .info)
            
            // Start the tunnel
            self.startOutlineTunnel { success in
                if success {
                    os_log("🎉 Tunnel started successfully!", log: self.logger, type: .info)
                    completionHandler(nil)
                } else {
                    os_log("❌ Failed to start tunnel", log: self.logger, type: .error)
                    let error = NSError(domain: "TeachGateVPN", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to start tunnel"])
                    completionHandler(error)
                }
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        os_log("🛑 Stopping tunnel with reason: %d", log: logger, type: .info, reason.rawValue)
        
        // Stop the tunnel
        #if canImport(Tun2socks)
        tunnel?.disconnect()
        #endif
        tunnel = nil
        shadowsocksClient = nil
        
        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        os_log("📨 Received app message", log: logger, type: .info)
        
        // Handle messages from the main app if needed
        completionHandler?(nil)
    }

    override func sleep(completionHandler: @escaping () -> Void) {
        os_log("😴 Entering sleep mode", log: logger, type: .info)
        completionHandler()
    }

    override func wake() {
        os_log("⏰ Waking up from sleep", log: logger, type: .info)
    }
    
    // MARK: - Private Methods
    
    private func extractVpnConfiguration() {
        os_log("🔍 Extracting VPN configuration", log: logger, type: .info)
        
        // Try to get configuration from protocol configuration first
        if let tunnelProtocol = protocolConfiguration as? NETunnelProviderProtocol,
           let providerConfiguration = tunnelProtocol.providerConfiguration {
            
            vpnConfig = [
                "host": providerConfiguration["host"] as? String ?? "",
                "port": providerConfiguration["port"] as? NSNumber ?? 0,
                "password": providerConfiguration["password"] as? String ?? "",
                "method": providerConfiguration["method"] as? String ?? "chacha20-ietf-poly1305",
                "prefix": providerConfiguration["prefix"] as? String ?? "",
                "tunnelId": providerConfiguration["tunnelId"] as? String ?? ""
            ]
            
            os_log("✅ VPN Configuration extracted from protocol", log: logger, type: .info)
            logConfigurationDetails()
            return
        }
        
        os_log("⚠️ No protocol configuration found, trying App Group", log: logger, type: .info)
        
        // Fallback to App Group shared configuration
        guard let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            os_log("❌ Failed to get App Group container URL for: %@", log: logger, type: .error, appGroup)
            return
        }
        
        let configURL = appGroupURL.appendingPathComponent("vpn-config.json")
        
        do {
            let configData = try Data(contentsOf: configURL)
            if let config = try JSONSerialization.jsonObject(with: configData) as? [String: Any] {
                vpnConfig = config
                os_log("✅ VPN configuration loaded from App Group: %@", log: logger, type: .info, configURL.path)
                logConfigurationDetails()
            } else {
                os_log("❌ Invalid VPN configuration format", log: logger, type: .error)
            }
        } catch {
            os_log("❌ Failed to load VPN configuration from App Group: %@", log: logger, type: .error, error.localizedDescription)
        }
    }
    
    private func logConfigurationDetails() {
        if let host = vpnConfig["host"] as? String,
           let port = vpnConfig["port"] as? NSNumber,
           let method = vpnConfig["method"] as? String {
            os_log("📋 Config Details - Host: %@, Port: %@, Method: %@", log: logger, type: .info, host, port, method)
        } else {
            os_log("⚠️ Incomplete configuration data", log: logger, type: .info)
        }
    }
    
    private func startOutlineTunnel(completion: @escaping (Bool) -> Void) {
        guard let host = vpnConfig["host"] as? String,
              let port = vpnConfig["port"] as? NSNumber,
              let password = vpnConfig["password"] as? String,
              let method = vpnConfig["method"] as? String,
              !host.isEmpty, !password.isEmpty else {
            os_log("❌ Invalid VPN configuration in startOutlineTunnel", log: logger, type: .error)
            completion(false)
            return
        }
        
        os_log("🔧 Starting Outline tunnel with Shadowsocks config", log: logger, type: .info)
        
        #if canImport(Tun2socks)
        os_log("✅ Tun2socks framework available", log: logger, type: .info)
        
        // Create Shadowsocks configuration
        let shadowsocksConfig = ShadowsocksConfig()
        shadowsocksConfig.host = host
        shadowsocksConfig.port = port.intValue
        shadowsocksConfig.password = password
        shadowsocksConfig.cipherName = method
        
        // Create prefix if available
        if let prefixString = vpnConfig["prefix"] as? String, !prefixString.isEmpty {
            shadowsocksConfig.prefix = Data(prefixString.utf8)
            os_log("🔑 Added prefix to Shadowsocks config", log: logger, type: .info)
        }
        
        os_log("🏗️ Creating Shadowsocks client...", log: logger, type: .info)
        
        // Create Shadowsocks client
        var error: NSError?
        shadowsocksClient = ShadowsocksNewClient(shadowsocksConfig, &error)
        
        if let error = error {
            os_log("❌ Failed to create Shadowsocks client: %@", log: logger, type: .error, error.localizedDescription)
            completion(false)
            return
        }
        
        guard let client = shadowsocksClient else {
            os_log("❌ Shadowsocks client is nil", log: logger, type: .error)
            completion(false)
            return
        }
        
        os_log("✅ Shadowsocks client created successfully", log: logger, type: .info)
        os_log("🚇 Creating tunnel connection...", log: logger, type: .info)
        
        // Create tunnel
        tunnel = Tun2socksConnectShadowsocksTunnel(self, client, true, &error)
        
        if let error = error {
            os_log("❌ Failed to create tunnel: %@", log: logger, type: .error, error.localizedDescription)
            completion(false)
            return
        }
        
        guard let tunnel = tunnel else {
            os_log("❌ Tunnel is nil", log: logger, type: .error)
            completion(false)
            return
        }
        
        // Check connection status
        let isConnected = tunnel.isConnected()
        os_log("🔍 Tunnel connection status: %@", log: logger, type: .info, isConnected ? "CONNECTED" : "NOT CONNECTED")
        
        if isConnected {
            os_log("🎉 Tunnel connected successfully!", log: logger, type: .info)
            startPacketProcessing()
            completion(true)
        } else {
            os_log("❌ Tunnel failed to connect", log: logger, type: .error)
            completion(false)
        }
        #else
        // Fallback implementation for testing without Tun2socks
        os_log("⚠️ Tun2socks framework not available, using fallback implementation", log: logger, type: .info)
        
        // Simple packet processing for testing
        startBasicPacketProcessing()
        completion(true)
        #endif
    }
    
    private func startPacketProcessing() {
        os_log("📦 Starting packet processing loop", log: logger, type: .info)
        readPackets()
    }
    
    private func readPackets() {
        packetFlow.readPackets { [weak self] packets, protocols in
            guard let self = self else { return }
            
            if packets.count > 0 {
                os_log("📨 Received %d packets", log: self.logger, type: .debug, packets.count)
                
                #if canImport(Tun2socks)
                // Process packets through Tun2socks tunnel
                for packet in packets {
                    var bytesWritten: Int = 0
                    let success = self.tunnel?.write(packet, ret0_: &bytesWritten, error: nil) ?? false
                    
                    if !success {
                        os_log("❌ Failed to write packet to tunnel", log: self.logger, type: .error)
                    }
                }
                #endif
            }
            
            // Continue reading packets
            self.readPackets()
        }
    }
    
    private func startBasicPacketProcessing() {
        os_log("📦 Starting basic packet processing (fallback)", log: logger, type: .info)
        
        packetFlow.readPackets { [weak self] packets, protocols in
            guard let self = self else { return }
            
            // Basic echo implementation for testing
            for (index, packet) in packets.enumerated() {
                let protocolNumber = protocols[index]
                // Echo packet back (this won't actually route traffic)
                self.packetFlow.writePackets([packet], withProtocols: [protocolNumber])
            }
            
            // Continue reading
            self.startBasicPacketProcessing()
        }
    }
}

// MARK: - Tun2socks Protocol Conformance

#if canImport(Tun2socks)
extension PacketTunnelProvider: Tun2socksTunnelDelegate {
    
    func tun2SocksTunnel(_ tunnel: Tun2socksTunnel, didReceiveData data: Data) {
        // Write received data to packet flow
        let protocols = [NSNumber(value: AF_INET)]
        self.packetFlow.writePackets([data], withProtocols: protocols)
    }
    
    func tun2SocksTunnel(_ tunnel: Tun2socksTunnel, didFailWithError error: Error) {
        os_log("❌ Tun2socks tunnel failed with error: %@", log: logger, type: .error, error.localizedDescription)
    }
}
#endif
