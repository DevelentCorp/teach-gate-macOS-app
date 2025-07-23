import Foundation
import NetworkExtension

@objc(TeachGateVpn)
class TeachGateVpn: NSObject {

  private var vpnManager = NEVPNManager.shared()
  private var status: NEVPNStatus = .invalid

  override init() {
    super.init()
    NotificationCenter.default.addObserver(self, selector: #selector(vpnStatusChanged), name: .NEVPNStatusDidChange, object: nil)
  }

  @objc(startVpn:withResolver:withRejecter:)
  func startVpn(config: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    let tunnelProtocol = NEPacketTunnelProvider()
    
    // The bundle ID of the containing app and the NE must match.
    tunnelProtocol.providerBundleIdentifier = "com.teachgate.TeachGateDeskApp.PacketTunnel"
    tunnelProtocol.serverAddress = "TeachGate" // Arbitrary address.
    
    vpnManager.protocolConfiguration = tunnelProtocol
    vpnManager.localizedDescription = "TeachGate VPN"
    vpnManager.isEnabled = true
    
    vpnManager.saveToPreferences { (error) in
      if let error = error {
        reject("vpn_save_error", "Failed to save VPN configuration: \(error.localizedDescription)", error)
        return
      }
      
      do {
        // Pass the config to the tunnel provider.
        let options = ["config": config]
        try self.vpnManager.connection.startVPNTunnel(options: options as [String : NSObject])
        resolve(nil)
      } catch {
        reject("vpn_start_error", "Failed to start VPN tunnel: \(error.localizedDescription)", error)
      }
    }
  }

  @objc(stopVpn:withRejecter:)
  func stopVpn(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    vpnManager.connection.stopVPNTunnel()
    resolve(nil)
  }

  @objc(getStatus:withRejecter:)
  func getStatus(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    resolve(status.description)
  }

  @objc
  private func vpnStatusChanged() {
    self.status = vpnManager.connection.status
  }
}

extension NEVPNStatus {
    var description: String {
        switch self {
        case .connected: return "connected"
        case .connecting: return "connecting"
        case .disconnected: return "disconnected"
        case .disconnecting: return "disconnecting"
        case .invalid: return "invalid"
        @unknown default: return "unknown"
        }
    }
}