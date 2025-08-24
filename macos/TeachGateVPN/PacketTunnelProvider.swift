import Foundation
import NetworkExtension
import os.log

// Minimal VPN Extension for Comprehensive Testing
@objc class PacketTunnelProvider: NEPacketTunnelProvider {
    
    private let logger = OSLog(subsystem: "com.teachgatedesk.develentcorp.TeachGateVPN", category: "VPN")
    
    override func startTunnel(options: [String : NSObject]? = nil, completionHandler: @escaping (Error?) -> Void) {
        os_log("🚀 VPN TEST: Starting tunnel with options: %@", log: logger, type: .info, String(describing: options))
        
        // CRITICAL VPN TESTING CHECKPOINT 1: Configuration Parsing
        guard let protocolConfig = self.protocolConfiguration as? NETunnelProviderProtocol else {
            os_log("❌ VPN TEST: Failed to retrieve tunnel configuration", log: logger, type: .error)
            completionHandler(VPNError.noConfiguration)
            return
        }
        
        // CRITICAL VPN TESTING CHECKPOINT 2: Server Configuration
        guard let serverConfig = protocolConfig.providerConfiguration?["transport"] as? String else {
            os_log("❌ VPN TEST: No server configuration found", log: logger, type: .error)  
            completionHandler(VPNError.noServerConfig)
            return
        }
        
        os_log("🔧 VPN TEST: Server config received: %@", log: logger, type: .info, serverConfig)
        
        // CRITICAL VPN TESTING CHECKPOINT 3: Network Settings Creation
        let tunnelNetworkSettings = createTunnelSettings()
        
        // CRITICAL VPN TESTING CHECKPOINT 4: Route Configuration
        setTunnelNetworkSettings(tunnelNetworkSettings) { [weak self] error in
            if let error = error {
                os_log("❌ VPN TEST: Failed to set network settings: %@", log: self?.logger ?? OSLog.default, type: .error, error.localizedDescription)
                completionHandler(error)
                return
            }
            
            os_log("✅ VPN TEST: Network settings configured successfully", log: self?.logger ?? OSLog.default, type: .info)
            os_log("✅ VPN TEST: VPN tunnel established - READY FOR TRAFFIC TESTING", log: self?.logger ?? OSLog.default, type: .info)
            
            // CRITICAL VPN TESTING CHECKPOINT 5: Packet Processing Start
            self?.startPacketProcessing()
            completionHandler(nil)
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        os_log("🛑 VPN TEST: Stopping tunnel, reason: %d", log: logger, type: .info, reason.rawValue)
        os_log("🛑 VPN TEST: VPN tunnel disconnected", log: logger, type: .info)
        completionHandler()
    }
    
    // CRITICAL VPN TESTING FUNCTION: Network Settings Configuration
    private func createTunnelSettings() -> NEPacketTunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "96.126.107.202")
        
        // IPv4 Settings - Route all traffic through VPN
        let ipv4Settings = NEIPv4Settings(addresses: ["10.0.0.2"], subnetMasks: ["255.255.255.0"])
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4Settings
        
        // DNS Settings - Use secure DNS
        let dnsSettings = NEDNSSettings(servers: ["1.1.1.1", "1.0.0.1"])
        settings.dnsSettings = dnsSettings
        
        os_log("📡 VPN TEST: Network settings created - IP: 10.0.0.2, DNS: 1.1.1.1", log: logger, type: .info)
        
        return settings
    }
    
    // CRITICAL VPN TESTING FUNCTION: Packet Processing (Traffic Flow Simulation)
    private func startPacketProcessing() {
        os_log("📦 VPN TEST: Starting packet processing for traffic flow testing", log: logger, type: .info)
        
        // Read packets from the TUN interface
        self.packetFlow.readPackets { [weak self] packets, protocols in
            guard let self = self else { return }
            
            os_log("📦 VPN TEST: Processing %d packets", log: self.logger, type: .debug, packets.count)
            
            // For testing purposes, log packet information
            for (index, packet) in packets.enumerated() {
                let packetSize = packet.count
                let protocolNumber = protocols[index].intValue
                os_log("📦 VPN TEST: Packet %d - Size: %d bytes, Protocol: %d", log: self.logger, type: .debug, index, packetSize, protocolNumber)
            }
            
            // In a real VPN, packets would be encrypted and sent to the server
            // For testing, we'll simulate this process
            self.simulateVPNProcessing(packets: packets, protocols: protocols)
            
            // Continue reading packets
            self.startPacketProcessing()
        }
    }
    
    // CRITICAL VPN TESTING FUNCTION: VPN Processing Simulation
    private func simulateVPNProcessing(packets: [Data], protocols: [NSNumber]) {
        os_log("🔒 VPN TEST: Simulating VPN encryption and forwarding for %d packets", log: logger, type: .debug, packets.count)
        
        // Simulate network processing delay
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.01) { [weak self] in
            // Simulate returning processed packets (in real VPN, these would come from the server)
            // For testing, we'll echo them back to demonstrate traffic flow
            self?.packetFlow.writePackets(packets, withProtocols: protocols)
        }
    }
    
    // Handle app messages (for testing communication)
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        let message = String(data: messageData, encoding: .utf8) ?? "unknown"
        os_log("📱 VPN TEST: Received app message: %@", log: logger, type: .info, message)
        
        let response = ["status": "connected", "server": "96.126.107.202:19834", "method": "chacha20-ietf-poly1305"]
        let responseData = try? JSONSerialization.data(withJSONObject: response)
        completionHandler?(responseData)
    }
}

// VPN Error Types for Testing
enum VPNError: Error {
    case noConfiguration
    case noServerConfig
    case connectionFailed
    
    var localizedDescription: String {
        switch self {
        case .noConfiguration:
            return "No VPN configuration provided"
        case .noServerConfig:
            return "No server configuration found"
        case .connectionFailed:
            return "Failed to connect to VPN server"
        }
    }
}