import Foundation
import NetworkExtension
import SystemConfiguration
import Security
import os.log

#if canImport(React)
import React

// Define RCTResponseSenderBlock for macOS
typealias RCTResponseSenderBlock = ([Any]) -> Void
#endif

@objc(OutlineVpn)
class OutlineVpn: NSObject {
    
    private let logger = OSLog(subsystem: "com.teachgate.vpn", category: "OutlineVpn")
    private let appGroup = "group.com.teachgatedesk.develentcorp"
    private let providerBundleIdentifier = "com.teachgatedesk.develentcorp.TeachGateVPN"
    private var statusObserver: NSObjectProtocol?
    
    override init() {
        super.init()
        setupStatusNotifications()
    }
    
    deinit {
        if let observer = statusObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupStatusNotifications() {
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.logVpnStatus()
        }
    }
    
    private func logVpnStatus() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            guard let self = self, let managers = managers, !managers.isEmpty else { return }
            let manager = managers.first!
            let statusString = self.vpnStatusString(manager.connection.status)
            os_log("📊 VPN Status Changed: %@", log: self.logger, type: .info, statusString)
        }
    }
    
    private func vpnStatusString(_ status: NEVPNStatus) -> String {
        switch status {
        case .invalid: return "INVALID"
        case .disconnected: return "DISCONNECTED"
        case .connecting: return "CONNECTING"
        case .connected: return "CONNECTED"
        case .reasserting: return "REASSERTING"
        case .disconnecting: return "DISCONNECTING"
        @unknown default: return "UNKNOWN"
        }
    }
    
    @objc
    static func requiresMainQueueSetup() -> Bool {
        return true
    }
    
    @objc
    func startVpn(
        _ host: String,
        port: NSNumber,
        password: String,
        method: String,
        prefix: String,
        providerBundleIdentifier: String?,
        serverAddress: String?,
        tunnelId: String?,
        localizedDescription: String?,
        successCallback: @escaping ([Any]) -> Void,
        errorCallback: @escaping ([Any]) -> Void
    ) {
        
        os_log("🚀 Starting VPN - Host: %@, Port: %@, Method: %@", log: logger, type: .info, host, port, method)
        
        let bundleId = providerBundleIdentifier ?? self.providerBundleIdentifier
        
        // Validate configuration
        guard !host.isEmpty, !password.isEmpty, !method.isEmpty else {
            os_log("❌ Invalid VPN configuration provided", log: logger, type: .error)
            DispatchQueue.main.async {
                errorCallback(["Invalid VPN configuration provided"])
            }
            return
        }
        
        // Save configuration to App Group for Network Extension
        let config = [
            "host": host,
            "port": port,
            "password": password,
            "method": method,
            "prefix": prefix,
            "tunnelId": tunnelId ?? "TeachGateVPN",
            "serverAddress": serverAddress ?? host
        ] as [String : Any]
        
        let configSaved = saveVpnConfigToAppGroup(config)
        if !configSaved {
            os_log("❌ Failed to save VPN config to App Group", log: logger, type: .error)
            DispatchQueue.main.async {
                errorCallback(["Failed to save VPN configuration"])
            }
            return
        }
        
        os_log("✅ VPN config saved to App Group", log: logger, type: .info)
        
        // Remove existing VPN configuration
        removeVpnConfiguration { [weak self] in
            guard let self = self else { return }
            
            // Create new VPN configuration
            let vpnManager = NETunnelProviderManager()
            let vpnProtocol = NETunnelProviderProtocol()
            
            // Configure the tunnel provider
            vpnProtocol.providerBundleIdentifier = bundleId
            vpnProtocol.serverAddress = serverAddress ?? host
            
            // Configure provider-specific settings (this is also passed to the extension)
            vpnProtocol.providerConfiguration = config
            
            vpnManager.protocolConfiguration = vpnProtocol
            vpnManager.localizedDescription = localizedDescription ?? "Teach Gate VPN"
            vpnManager.isEnabled = true
            
            os_log("💾 Saving VPN preferences...", log: self.logger, type: .info)
            
            // Save the configuration
            vpnManager.saveToPreferences { error in
                if let error = error {
                    os_log("❌ Failed to save VPN preferences: %@", log: self.logger, type: .error, error.localizedDescription)
                    DispatchQueue.main.async {
                        errorCallback(["Failed to save VPN configuration: \(error.localizedDescription)"])
                    }
                    return
                }
                
                os_log("✅ VPN preferences saved successfully", log: self.logger, type: .info)
                
                // Load the configuration and start the VPN
                vpnManager.loadFromPreferences { error in
                    if let error = error {
                        os_log("❌ Failed to load VPN preferences: %@", log: self.logger, type: .error, error.localizedDescription)
                        DispatchQueue.main.async {
                            errorCallback(["Failed to load VPN configuration: \(error.localizedDescription)"])
                        }
                        return
                    }
                    
                    // Check current status before starting
                    let currentStatus = vpnManager.connection.status
                    os_log("📊 Current VPN status before start: %@", log: self.logger, type: .info, self.vpnStatusString(currentStatus))
                    
                    do {
                        try vpnManager.connection.startVPNTunnel()
                        os_log("🚇 VPN tunnel start initiated successfully", log: self.logger, type: .info)
                        
                        // Monitor connection status
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            let statusAfterStart = vpnManager.connection.status
                            os_log("📊 VPN status after start attempt: %@", log: self.logger, type: .info, self.vpnStatusString(statusAfterStart))
                        }
                        
                        DispatchQueue.main.async {
                            successCallback(["VPN connection started successfully"])
                        }
                    } catch {
                        os_log("❌ Failed to start VPN tunnel: %@", log: self.logger, type: .error, error.localizedDescription)
                        DispatchQueue.main.async {
                            errorCallback(["Failed to start VPN tunnel: \(error.localizedDescription)"])
                        }
                    }
                }
            }
        }
    }
    
    @objc
    func disconnectVpn(
        _ options: Any?,
        successCallback: @escaping ([Any]) -> Void,
        errorCallback: @escaping ([Any]) -> Void
    ) {
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            if let error = error {
                DispatchQueue.main.async {
                    errorCallback(["Failed to load VPN managers: \(error.localizedDescription)"])
                }
                return
            }
            
            guard let managers = managers, !managers.isEmpty else {
                DispatchQueue.main.async {
                    successCallback(["No VPN configuration found"])
                }
                return
            }
            
            let manager = managers.first!
            
            if manager.connection.status == .connected || manager.connection.status == .connecting {
                manager.connection.stopVPNTunnel()
                DispatchQueue.main.async {
                    successCallback(["VPN disconnected successfully"])
                }
            } else {
                DispatchQueue.main.async {
                    successCallback(["VPN was not connected"])
                }
            }
        }
    }
    
    @objc
    func getVpnConnectionStatus(_ callback: @escaping ([Any]) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            if let error = error {
                DispatchQueue.main.async {
                    callback([error.localizedDescription, false])
                }
                return
            }
            
            guard let managers = managers, !managers.isEmpty else {
                DispatchQueue.main.async {
                    callback([NSNull(), false])
                }
                return
            }
            
            let manager = managers.first!
            let isConnected = manager.connection.status == .connected
            
            DispatchQueue.main.async {
                callback([NSNull(), isConnected])
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func removeVpnConfiguration(completion: @escaping () -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            guard let managers = managers, !managers.isEmpty else {
                completion()
                return
            }
            
            let group = DispatchGroup()
            
            for manager in managers {
                group.enter()
                manager.removeFromPreferences { _ in
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                completion()
            }
        }
    }
    
    private func saveVpnConfigToAppGroup(_ config: [String: Any]) -> Bool {
        guard let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            os_log("❌ Failed to get App Group container URL for: %@", log: logger, type: .error, appGroup)
            return false
        }
        
        let configURL = appGroupURL.appendingPathComponent("vpn-config.json")
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: config, options: .prettyPrinted)
            try jsonData.write(to: configURL)
            os_log("✅ VPN configuration saved to App Group at: %@", log: logger, type: .info, configURL.path)
            
            // Verify the file was written correctly
            let savedData = try Data(contentsOf: configURL)
            if let savedConfig = try JSONSerialization.jsonObject(with: savedData) as? [String: Any] {
                os_log("✅ Verified saved config contains %d keys", log: logger, type: .info, savedConfig.keys.count)
                return true
            } else {
                os_log("❌ Failed to verify saved config", log: logger, type: .error)
                return false
            }
        } catch {
            os_log("❌ Failed to save VPN configuration: %@", log: logger, type: .error, error.localizedDescription)
            return false
        }
    }
}

// MARK: - React Native Bridge

#if canImport(React)
@objc(OutlineVpnBridge)
class OutlineVpnBridge: RCTEventEmitter {
    
    override func supportedEvents() -> [String]! {
        return ["VPNStatusChanged"]
    }
    
    @objc
    override static func requiresMainQueueSetup() -> Bool {
        return true
    }
}
#endif