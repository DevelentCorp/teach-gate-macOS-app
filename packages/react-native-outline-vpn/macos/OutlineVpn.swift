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
    
    private let logger = OSLog(subsystem: "com.teachgatedesk.develentcorp", category: "OutlineVpn")
    private let appGroup = "group.com.teachgatedesk.develentcorp"
    private let providerBundleIdentifier = "com.teachgatedesk.develentcorp.TeachGateVPN"
    private var statusObserver: NSObjectProtocol?
    private var lastStatusLogTime: Date = Date.distantPast
    private let statusLogThrottle: TimeInterval = 1.0 // Only log status changes once per second
    // Track last tunnelId used so we can query status via OutlineVpnProduction
    private var lastTunnelId: String?
    
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
    
    // MARK: - Error Mapping (OutlineError integration)
    private func mapOutlineError(_ error: Error) -> String {
        // Use LocalizedError to avoid hard dependency on the concrete type at compile-time.
        if let localized = (error as? LocalizedError)?.errorDescription {
            return localized
        }
        return error.localizedDescription
    }
    
    @objc
    static func requiresMainQueueSetup() -> Bool {
        return true
    }
    
    @objc
    func startVpn(
        _ config: NSDictionary,
        successCallback: @escaping ([Any]) -> Void,
        errorCallback: @escaping ([Any]) -> Void
    ) {
        // Parse Outline-Apps style configuration dictionary.
        // Expected keys:
        // - id: String
        // - name: String? (aka localized description)
        // - transport: String | Dictionary (will be serialized to JSON String)
        // - autoConnect: Bool?
        // - onDemandRules: [Dictionary]?
        // - connectivityCheck: Dictionary?
        os_log("🚀 Starting VPN with Outline-Apps config format", log: logger, type: .info)
        
        guard let cfg = config as? [String: Any] else {
            os_log("❌ Invalid config: not a dictionary", log: logger, type: .error)
            DispatchQueue.main.async {
                errorCallback(["Invalid VPN configuration provided"])
            }
            return
        }
        
        // Backward-compat shim: if legacy fields exist (host/port/password/method), build transport.
        var effectiveConfig = cfg
        if effectiveConfig["transport"] == nil,
           let host = effectiveConfig["host"] as? String,
           let port = effectiveConfig["port"],
           let password = effectiveConfig["password"] as? String,
           let method = effectiveConfig["method"] as? String {
            let prefix = (effectiveConfig["prefix"] as? String) ?? ""
            let legacyTransport: [String: Any] = [
                "host": host,
                "port": port,
                "password": password,
                "method": method,
                "prefix": prefix
            ]
            effectiveConfig["transport"] = legacyTransport
            if effectiveConfig["id"] == nil {
                effectiveConfig["id"] = effectiveConfig["tunnelId"] as? String ?? "TeachGateVPN"
            }
            if effectiveConfig["name"] == nil {
                effectiveConfig["name"] = effectiveConfig["localizedDescription"] as? String ?? "Teach Gate VPN"
            }
        }
        
        let tunnelIdToUse = (effectiveConfig["id"] as? String) ?? "TeachGateVPN"
        let name = (effectiveConfig["name"] as? String) ?? "Teach Gate VPN"
        let autoConnect = effectiveConfig["autoConnect"] as? Bool
        let onDemandRules = effectiveConfig["onDemandRules"] as? [[String: Any]]
        let connectivityCheck = effectiveConfig["connectivityCheck"] as? [String: Any]
        
        // Build transport JSON string
        var transportConfigString: String?
        if let transportString = effectiveConfig["transport"] as? String {
            transportConfigString = transportString
        } else if let transportDict = effectiveConfig["transport"] as? [String: Any] {
            do {
                let data = try JSONSerialization.data(withJSONObject: transportDict, options: [])
                transportConfigString = String(data: data, encoding: .utf8)
            } catch {
                os_log("❌ Failed to serialize transport: %@", log: logger, type: .error, error.localizedDescription)
            }
        }
        
        guard let transportConfig = transportConfigString, !transportConfig.isEmpty else {
            os_log("❌ Missing or invalid transport configuration", log: logger, type: .error)
            DispatchQueue.main.async {
                errorCallback(["Invalid VPN configuration: missing transport"])
            }
            return
        }
        
        // Use Task to handle async production VPN implementation
        Task {
            do {
                try await OutlineVpnProduction.shared.start(
                    tunnelIdToUse,
                    named: name,
                    withTransport: transportConfig,
                    autoConnect: autoConnect,
                    onDemandRules: onDemandRules,
                    connectivityCheck: connectivityCheck
                )
                self.lastTunnelId = tunnelIdToUse
                DispatchQueue.main.async {
                    successCallback(["VPN connection started successfully"])
                }
            } catch {
                os_log("❌ Production VPN start failed: %@", log: self.logger, type: .error, error.localizedDescription)
                DispatchQueue.main.async {
                    errorCallback(["Failed to start VPN: \(self.mapOutlineError(error))"])
                }
            }
        }
    }
    
    // Using OutlineVpnProduction for all start/stop/status operations.
    
    
    
    @objc
    func disconnectVpn(
        _ options: Any?,
        successCallback: @escaping ([Any]) -> Void,
        errorCallback: @escaping ([Any]) -> Void
    ) {
        os_log("🛑 Disconnecting VPN with production implementation", log: logger, type: .info)
        
        Task {
            await OutlineVpnProduction.shared.stopActiveVpn()
            DispatchQueue.main.async {
                successCallback(["VPN disconnected successfully"])
            }
        }
    }
    
    
    @objc
    func getVpnConnectionStatus(_ callback: @escaping ([Any]) -> Void) {
        os_log("📊 Checking VPN connection status with production implementation", log: logger, type: .info)
        
        Task {
            let isActive = await OutlineVpnProduction.shared.isActive(self.lastTunnelId)
            DispatchQueue.main.async {
                callback([NSNull(), isActive])
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
    
    // MARK: - Production VPN Helper Methods
    // All production VPN operations are delegated to OutlineVpnProduction.
}

// MARK: - React Native Bridge

#if canImport(React)
@objc(OutlineVpnBridge)
class OutlineVpnBridge: RCTEventEmitter {
    private var isObserving = false

    override func supportedEvents() -> [String]! {
        return ["VPNStatusChanged"]
    }

    @objc
    override static func requiresMainQueueSetup() -> Bool {
        return true
    }

    override func startObserving() {
        isObserving = true
        OutlineVpnProduction.shared.onVpnStatusChange { [weak self] status, tunnelId in
            guard let self = self, self.isObserving else { return }
            self.sendEvent(withName: "VPNStatusChanged", body: [
                "status": self.statusString(status),
                "tunnelId": tunnelId
            ])
        }
    }

    override func stopObserving() {
        isObserving = false
        // Remove observer by installing a no-op handler
        OutlineVpnProduction.shared.onVpnStatusChange { _, _ in }
    }

    private func statusString(_ status: NEVPNStatus) -> String {
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
}
#endif