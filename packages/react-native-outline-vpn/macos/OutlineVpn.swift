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
    private var lastStatusLogTime: Date = Date.distantPast
    private let statusLogThrottle: TimeInterval = 1.0 // Only log status changes once per second
    
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
        // Temporarily disable status notifications to prevent log flooding
        // This will be re-enabled once the VPN state cycling issue is resolved
        /*
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.logVpnStatus(from: notification)
        }
        */
    }
    
    private func logVpnStatus(from notification: Notification) {
        // Throttle status logging to prevent flooding
        let now = Date()
        guard now.timeIntervalSince(lastStatusLogTime) >= statusLogThrottle else { return }
        lastStatusLogTime = now
        
        // Extract status from notification object if possible
        if let connection = notification.object as? NEVPNConnection {
            let statusString = vpnStatusString(connection.status)
            os_log("📊 VPN Status Changed: %@", log: logger, type: .info, statusString)
        } else {
            // Fallback - only log that a status change occurred without triggering loadAllFromPreferences
            os_log("📊 VPN Status Change Notification Received", log: logger, type: .info)
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
    
    // MARK: - VPN Error Types
    private enum VpnError: Error {
        case vpnPermissionNotGranted(cause: Error)
        case setupSystemVPNFailed(cause: Error)
        case internalError(message: String)
    }
    
    private func mapProductionError(_ error: Error) -> String {
        if let vpnError = error as? VpnError {
            switch vpnError {
            case .vpnPermissionNotGranted(let cause):
                return "VPN permission not granted: \(cause.localizedDescription)"
            case .setupSystemVPNFailed(let cause):
                return "Failed to setup system VPN: \(cause.localizedDescription)"
            case .internalError(let message):
                return "Internal error: \(message)"
            }
        }
        return error.localizedDescription
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
        
        os_log("🚀 Starting VPN with production implementation - Host: %@, Port: %@, Method: %@", log: logger, type: .info, host, port, method)
        
        let bundleId = providerBundleIdentifier ?? self.providerBundleIdentifier
        let tunnelIdToUse = tunnelId ?? "TeachGateVPN"
        
        // Validate configuration
        guard !host.isEmpty, !password.isEmpty, !method.isEmpty else {
            os_log("❌ Invalid VPN configuration provided", log: logger, type: .error)
            DispatchQueue.main.async {
                errorCallback(["Invalid VPN configuration provided"])
            }
            return
        }
        
        // Create transport configuration in format expected by production implementation
        let transportConfig = """
        {
            "host": "\(host)",
            "port": \(port),
            "password": "\(password)",
            "method": "\(method)",
            "prefix": "\(prefix.isEmpty ? "" : prefix)"
        }
        """
        
        // Use Task to handle async production VPN implementation
        Task {
            do {
                try await self.startProductionVpn(
                    tunnelId: tunnelIdToUse,
                    name: localizedDescription ?? "Teach Gate VPN",
                    transportConfig: transportConfig
                )
                
                DispatchQueue.main.async {
                    successCallback(["VPN connection started successfully"])
                }
            } catch {
                os_log("❌ Production VPN start failed: %@", log: self.logger, type: .error, error.localizedDescription)
                DispatchQueue.main.async {
                    errorCallback(["Failed to start VPN: \(self.mapProductionError(error))"])
                }
            }
        }
    }
    
    // Production-style VPN start implementation
    private func startProductionVpn(tunnelId: String, name: String, transportConfig: String) async throws {
        // Stop any existing active session
        if let manager = await getTunnelManager(), isActiveSession(manager.connection) {
            os_log("Stopping active session before starting new one", log: logger, type: .debug)
            await stopSession(manager)
        }

        let manager: NETunnelProviderManager
        do {
            manager = try await setupProductionVpn(withId: tunnelId, named: name, withTransport: transportConfig)
        } catch {
            os_log("Failed to setup VPN: %@", log: logger, type: .error, error.localizedDescription)
            throw VpnError.vpnPermissionNotGranted(cause: error)
        }
        
        let session = manager.connection as! NETunnelProviderSession

        // Start the session with production-style error handling
        do {
            try session.startTunnel(options: [:])
            os_log("VPN tunnel start initiated successfully", log: logger, type: .info)
        } catch {
            os_log("Failed to start VPN: %@", log: logger, type: .error, error.localizedDescription)
            throw VpnError.setupSystemVPNFailed(cause: error)
        }

        // Wait for connection to complete
        try await waitForConnectionCompletion(manager: manager)
        
        // Set up on-demand rules for auto-connect
        await setOnDemandRules(manager: manager)
    }
    
    private func waitForConnectionCompletion(manager: NETunnelProviderManager) async throws {
        try await withCheckedThrowingContinuation { continuation in
            var observer: NSObjectProtocol?
            observer = NotificationCenter.default.addObserver(forName: .NEVPNStatusDidChange, object: manager.connection, queue: nil) { notification in
                guard let connection = notification.object as? NETunnelProviderSession else {
                    return
                }
                
                let status = connection.status
                os_log("VPN status during start: %@", log: self.logger, type: .debug, self.vpnStatusString(status))
                
                if status == .connected || status == .disconnected || status == .invalid {
                    if let obs = observer {
                        NotificationCenter.default.removeObserver(obs, name: .NEVPNStatusDidChange, object: connection)
                    }
                    
                    switch status {
                    case .connected:
                        continuation.resume()
                    case .disconnected, .invalid:
                        continuation.resume(throwing: VpnError.internalError(message: "Connection failed"))
                    default:
                        continuation.resume(throwing: VpnError.internalError(message: "Unexpected connection status"))
                    }
                }
            }
        }
    }
    
    private func setOnDemandRules(manager: NETunnelProviderManager) async {
        do {
            try await manager.loadFromPreferences()
            let connectRule = NEOnDemandRuleConnect()
            connectRule.interfaceTypeMatch = .any
            manager.onDemandRules = [connectRule]
            try await manager.saveToPreferences()
        } catch {
            os_log("Failed to set on-demand rules: %@", log: logger, type: .error, error.localizedDescription)
        }
    }
    
    @objc
    func disconnectVpn(
        _ options: Any?,
        successCallback: @escaping ([Any]) -> Void,
        errorCallback: @escaping ([Any]) -> Void
    ) {
        os_log("🛑 Disconnecting VPN with production implementation", log: logger, type: .info)
        
        Task {
            do {
                await self.stopProductionVpn()
                DispatchQueue.main.async {
                    successCallback(["VPN disconnected successfully"])
                }
            } catch {
                os_log("❌ Production VPN stop failed: %@", log: self.logger, type: .error, error.localizedDescription)
                DispatchQueue.main.async {
                    errorCallback(["Failed to disconnect VPN: \(error.localizedDescription)"])
                }
            }
        }
    }
    
    // Production-style VPN stop implementation
    private func stopProductionVpn() async {
        guard let manager = await getTunnelManager(),
              isActiveSession(manager.connection) else {
            os_log("No active VPN session to stop", log: logger, type: .debug)
            return
        }
        await stopSession(manager)
    }
    
    @objc
    func getVpnConnectionStatus(_ callback: @escaping ([Any]) -> Void) {
        os_log("📊 Checking VPN connection status with production implementation", log: logger, type: .info)
        
        Task {
            let isActive = await self.isProductionVpnActive()
            DispatchQueue.main.async {
                callback([NSNull(), isActive])
            }
        }
    }
    
    // Production-style VPN status check implementation
    private func isProductionVpnActive() async -> Bool {
        guard let manager = await getTunnelManager() else {
            os_log("No VPN manager found for status check", log: logger, type: .debug)
            return false
        }
        
        let isActive = isActiveSession(manager.connection)
        os_log("VPN status check result: %@", log: logger, type: .debug, isActive ? "ACTIVE" : "INACTIVE")
        return isActive
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
    
    // MARK: - Production VPN Helper Methods
    
    private func getTunnelManager() async -> NETunnelProviderManager? {
        do {
            let managers: [NETunnelProviderManager] = try await NETunnelProviderManager.loadAllFromPreferences()
            return managers.first
        } catch {
            os_log("Failed to get tunnel manager: %@", log: logger, type: .error, error.localizedDescription)
            return nil
        }
    }
    
    private func isActiveSession(_ session: NEVPNConnection?) -> Bool {
        let vpnStatus = session?.status
        return vpnStatus == .connected || vpnStatus == .connecting || vpnStatus == .reasserting
    }
    
    private func stopSession(_ manager: NETunnelProviderManager) async {
        do {
            try await manager.loadFromPreferences()
            manager.connection.stopVPNTunnel()
            // Wait for stop to be completed
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                var observer: NSObjectProtocol?
                observer = NotificationCenter.default.addObserver(forName: .NEVPNStatusDidChange, object: manager.connection, queue: nil) { notification in
                    if manager.connection.status == .disconnected {
                        if let obs = observer {
                            NotificationCenter.default.removeObserver(obs, name: .NEVPNStatusDidChange, object: manager.connection)
                        }
                        continuation.resume()
                    }
                }
            }
        } catch {
            os_log("Failed to stop VPN: %@", log: logger, type: .error, error.localizedDescription)
        }
    }
    
    private func setupProductionVpn(withId id: String, named name: String, withTransport transportConfig: String) async throws -> NETunnelProviderManager {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        let manager: NETunnelProviderManager
        
        if managers.count > 0 {
            manager = managers.first!
        } else {
            manager = NETunnelProviderManager()
        }

        manager.localizedDescription = name
        manager.onDemandRules = nil

        // Configure the protocol
        let config = NETunnelProviderProtocol()
        config.serverAddress = "Outline"
        config.providerBundleIdentifier = providerBundleIdentifier
        config.providerConfiguration = [
            "id": id,
            "transport": transportConfig
        ]
        manager.protocolConfiguration = config
        manager.isEnabled = true

        try await manager.saveToPreferences()
        try await manager.loadFromPreferences()
        return manager
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