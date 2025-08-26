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
    public static let shared = OutlineVpn()
    
    private let logger = OSLog(subsystem: "com.teachgatedesk.develentcorp", category: "OutlineVpn")
    private let appGroup = "group.com.teachgatedesk.develentcorp"
    private let providerBundleIdentifier = "com.teachgatedesk.develentcorp.TeachGateVPN"
    private var statusObserver: NSObjectProtocol?
    private var lastStatusLogTime: Date = Date.distantPast
    private let statusLogThrottle: TimeInterval = 1.0 // Only log status changes once per second
    // Track last tunnelId used so we can query status via OutlineVpnProduction
    private var lastTunnelId: String?
    private var vpnStatusHandler: ((NEVPNStatus, String?) -> Void)?
    
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
        
        // Use Task to handle async VPN implementation (canonical Outline-Apps API)
        Task {
            do {
                try await OutlineVpn.shared.start(
                    tunnelIdToUse,
                    named: name,
                    withTransport: transportConfig
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
            await OutlineVpn.shared.stopActiveVpn()
            DispatchQueue.main.async {
                successCallback(["VPN disconnected successfully"])
            }
        }
    }
    
    
    @objc
    func getVpnConnectionStatus(_ callback: @escaping ([Any]) -> Void) {
        os_log("📊 Checking VPN connection status with production implementation", log: logger, type: .info)
        
        Task {
            let isActive = await OutlineVpn.shared.isActive(self.lastTunnelId)
            DispatchQueue.main.async {
                callback([NSNull(), isActive])
            }
        }
    }
    
    
    // MARK: - Private Methods
    
    private func removeVpnConfiguration(completion: @escaping () -> Void) {
        os_log("📝 removeVpnConfiguration: loading managers to remove", log: logger, type: .info)
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            if let err = error as NSError? {
                os_log("❌ removeVpnConfiguration: loadAllFromPreferences failed: domain=%{public}@ code=%{public}d userInfo=%{public}@", log: self.logger, type: .error, err.domain, err.code, String(describing: err.userInfo))
                completion()
                return
            } else if let error = error {
                os_log("❌ removeVpnConfiguration: loadAllFromPreferences failed with Error: %{public}@", log: self.logger, type: .error, String(describing: error))
                completion()
                return
            }
            guard let managers = managers, !managers.isEmpty else {
                os_log("ℹ️ removeVpnConfiguration: no managers present", log: self.logger, type: .info)
                completion()
                return
            }
            
            let group = DispatchGroup()
            
            for manager in managers {
                group.enter()
                os_log("🗑️ Removing manager: localizedDescription=%{public}@ providerBundleIdentifier=%{public}@", log: self.logger, type: .info, manager.localizedDescription ?? "<nil>", (manager.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier ?? "<nil>")
                manager.removeFromPreferences { err in
                    if let err = err as NSError? {
                        os_log("❌ removeFromPreferences failed: domain=%{public}@ code=%{public}d userInfo=%{public}@", log: self.logger, type: .error, err.domain, err.code, String(describing: err.userInfo))
                    } else if let err = err {
                        os_log("❌ removeFromPreferences failed with Error: %{public}@", log: self.logger, type: .error, String(describing: err))
                    } else {
                        os_log("✅ removeFromPreferences succeeded for manager.localizedDescription=%{public}@", log: self.logger, type: .info, manager.localizedDescription ?? "<nil>")
                    }
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
    
    // MARK: - VPN Operations (migrated from Outline-Apps OutlineVpn)

    // Registers a callback for VPN status changes.
    func onVpnStatusChange(_ handler: @escaping (NEVPNStatus, String?) -> Void) {
        self.vpnStatusHandler = handler
        // Recreate observer with the latest handler to avoid multiple notifications
        if let observer = statusObserver {
            NotificationCenter.default.removeObserver(observer)
            statusObserver = nil
        }
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            let status = (notification.object as? NEVPNConnection)?.status ?? .invalid
            self.vpnStatusHandler?(status, self.lastTunnelId)
        }
    }

    // Start the VPN by saving config to the App Group and bringing up the tunnel.
    func start(_ tunnelId: String,
               named name: String,
               withTransport transportConfig: String) async throws {

        var config: [String: Any] = [
            "id": tunnelId,
            "name": name,
            "transport": transportConfig
        ]

        _ = saveVpnConfigToAppGroup(config)

        let manager = try await loadOrCreateManager(named: name)
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = providerBundleIdentifier
        proto.serverAddress = "localhost"
        proto.providerConfiguration = ["id": tunnelId, "transport": transportConfig]

        manager.protocolConfiguration = proto
        manager.localizedDescription = name
        manager.isEnabled = true

        // Verbose saveToPreferences logging: capture NSError details (code, domain, userInfo) and manager metadata.
        os_log("📝 Saving NETunnelProviderManager to preferences. manager.localizedDescription=%{public}@ providerBundleIdentifier=%{public}@ isEnabled=%{public}@", log: logger, type: .info, manager.localizedDescription ?? "<nil>", proto.providerBundleIdentifier ?? "<nil>", String(manager.isEnabled))
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            manager.saveToPreferences { error in
                if let err = error as NSError? {
                    os_log("❌ saveToPreferences failed: domain=%{public}@ code=%{public}d userInfo=%{public}@", log: self.logger, type: .error, err.domain, err.code, String(describing: err.userInfo))
                    cont.resume(throwing: err)
                } else if let error = error {
                    // Non-NSError fallback
                    os_log("❌ saveToPreferences failed with Error: %{public}@", log: self.logger, type: .error, String(describing: error))
                    cont.resume(throwing: error)
                } else {
                    os_log("✅ saveToPreferences succeeded for manager.localizedDescription=%{public}@", log: self.logger, type: .info, manager.localizedDescription ?? "<nil>")
                    cont.resume()
                }
            }
        }

        // Reload to ensure the manager reflects saved preferences before starting.
        os_log("📝 Calling loadFromPreferences for manager.localizedDescription=%{public}@ providerBundleIdentifier=%{public}@", log: logger, type: .info, manager.localizedDescription ?? "<nil>", proto.providerBundleIdentifier ?? "<nil>")
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            manager.loadFromPreferences { error in
                if let err = error as NSError? {
                    os_log("❌ loadFromPreferences failed: domain=%{public}@ code=%{public}d userInfo=%{public}@", log: self.logger, type: .error, err.domain, err.code, String(describing: err.userInfo))
                    cont.resume(throwing: err)
                } else if let error = error {
                    os_log("❌ loadFromPreferences failed with Error: %{public}@", log: self.logger, type: .error, String(describing: error))
                    cont.resume(throwing: error)
                } else {
                    os_log("✅ loadFromPreferences succeeded for manager.localizedDescription=%{public}@", log: self.logger, type: .info, manager.localizedDescription ?? "<nil>")
                    cont.resume()
                }
            }
        }

        // Start the tunnel; manager already has providerConfiguration with id/transport.
        os_log("📝 Attempting startVPNTunnel. connection.status=%{public}d manager.localizedDescription=%{public}@", log: logger, type: .info, manager.connection.status.rawValue, manager.localizedDescription ?? "<nil>")
        do {
            try manager.connection.startVPNTunnel()
            os_log("✅ startVPNTunnel called successfully", log: logger, type: .info)
        } catch let err as NSError {
            os_log("❌ startVPNTunnel threw NSError: domain=%{public}@ code=%{public}d userInfo=%{public}@", log: self.logger, type: .error, err.domain, err.code, String(describing: err.userInfo))
            throw err
        } catch {
            os_log("❌ startVPNTunnel threw Error: %{public}@", log: self.logger, type: .error, String(describing: error))
            throw error
        }

        self.lastTunnelId = tunnelId
    }

    // Stop any active VPN connection started by this app.
    func stopActiveVpn() async {
        let managers = (try? await loadManagers()) ?? []
        for m in managers {
            if m.connection.status == .connected || m.connection.status == .connecting || m.connection.status == .reasserting {
                m.connection.stopVPNTunnel()
            }
        }
    }

    // Returns whether a VPN is currently connected (optionally for a given tunnelId).
    func isActive(_ tunnelId: String?) async -> Bool {
        let managers = (try? await loadManagers()) ?? []
        for m in managers {
            if m.connection.status == .connected {
                return true
            }
        }
        return false
    }

    // MARK: - Private helpers

    private func loadManagers() async throws -> [NETunnelProviderManager] {
        // Verbose loadAllFromPreferences wrapper to log NSError details and managers count.
        os_log("📝 Calling NETunnelProviderManager.loadAllFromPreferences()", log: logger, type: .info)
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[NETunnelProviderManager], Error>) in
            NETunnelProviderManager.loadAllFromPreferences { managers, error in
                if let err = error as NSError? {
                    os_log("❌ loadAllFromPreferences failed: domain=%{public}@ code=%{public}d userInfo=%{public}@", log: self.logger, type: .error, err.domain, err.code, String(describing: err.userInfo))
                    cont.resume(throwing: err)
                } else if let error = error {
                    os_log("❌ loadAllFromPreferences failed with Error: %{public}@", log: self.logger, type: .error, String(describing: error))
                    cont.resume(throwing: error)
                } else {
                    let count = managers?.count ?? 0
                    os_log("✅ loadAllFromPreferences returned %{public}d manager(s)", log: self.logger, type: .info, count)
                    // Log each manager's localizedDescription and its protocol providerBundleIdentifier if present
                    if let managers = managers {
                        for m in managers {
                            let desc = m.localizedDescription ?? "<nil>"
                            let pbid = (m.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier ?? "<nil>"
                            os_log("ℹ️ Manager found: localizedDescription=%{public}@ providerBundleIdentifier=%{public}@ isEnabled=%{public}@", log: self.logger, type: .info, desc, pbid, String(m.isEnabled))
                        }
                    }
                    cont.resume(returning: managers ?? [])
                }
            }
        }
    }

    private func loadOrCreateManager(named name: String) async throws -> NETunnelProviderManager {
        let managers = try await loadManagers()
        if let existing = managers.first(where: { ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == self.providerBundleIdentifier }) {
            return existing
        }
        let manager = NETunnelProviderManager()
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = providerBundleIdentifier
        proto.serverAddress = "localhost"
        manager.protocolConfiguration = proto
        manager.localizedDescription = name
        manager.isEnabled = true
        return manager
    }
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
        OutlineVpn.shared.onVpnStatusChange { [weak self] status, tunnelId in
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
        OutlineVpn.shared.onVpnStatusChange { _, _ in }
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