#!/usr/bin/env swift

import Foundation
import NetworkExtension

// Simple test to verify VPN configuration can be created and started
class VPNTest {
    
    static func main() {
        let test = VPNTest()
        test.testVPN()
        
        // Keep the program alive to see async results
        RunLoop.main.run()
    }
    
    func testVPN() {
        print("🧪 Testing VPN Extension Configuration...")
        
        // Create VPN configuration
        let manager = NETunnelProviderManager()
        let vpnProtocol = NETunnelProviderProtocol()
        
        vpnProtocol.providerBundleIdentifier = "com.develentcorp.teachgatedesk.tgvpn"
        vpnProtocol.serverAddress = "TeachGateServer"
        vpnProtocol.providerConfiguration = [
            "id": "test-tunnel",
            "transport": "{\"host\":\"example.com\",\"port\":8080}"
        ]
        
        manager.protocolConfiguration = vpnProtocol
        manager.localizedDescription = "TeachGate VPN Test"
        manager.isEnabled = true
        
        print("💾 Saving VPN configuration...")
        
        manager.saveToPreferences { error in
            if let error = error {
                print("❌ Failed to save VPN config: \(error.localizedDescription)")
                return
            }
            
            print("✅ VPN configuration saved successfully")
            
            // Test loading configuration
            NETunnelProviderManager.loadAllFromPreferences { managers, error in
                if let error = error {
                    print("❌ Failed to load VPN configs: \(error.localizedDescription)")
                    return
                }
                
                print("📋 Found \(managers?.count ?? 0) VPN configurations")
                
                guard let manager = managers?.first else {
                    print("❌ No VPN configuration found")
                    return
                }
                
                print("🔍 VPN Manager Details:")
                print("  - Bundle ID: \((manager.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier ?? "Unknown")")
                print("  - Description: \(manager.localizedDescription ?? "Unknown")")
                print("  - Enabled: \(manager.isEnabled)")
                print("  - Status: \(self.statusToString(manager.connection.status))")
                
                // Test starting the VPN
                print("🚀 Attempting to start VPN...")
                let session = manager.connection as! NETunnelProviderSession
                
                do {
                    try session.startTunnel(options: nil)
                    print("✅ VPN start command sent successfully")
                    
                    // Wait a bit to see status change
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        print("🔍 VPN Status after 3 seconds: \(self.statusToString(session.status))")
                        exit(0)
                    }
                } catch {
                    print("❌ Failed to start VPN: \(error.localizedDescription)")
                    exit(1)
                }
            }
        }
    }
    
    func statusToString(_ status: NEVPNStatus) -> String {
        switch status {
        case .invalid: return "Invalid"
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting"
        case .connected: return "Connected"
        case .reasserting: return "Reasserting"
        case .disconnecting: return "Disconnecting"
        @unknown default: return "Unknown"
        }
    }
}

VPNTest.main()