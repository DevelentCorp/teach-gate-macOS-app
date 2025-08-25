// Copyright 2018 The Outline Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import NetworkExtension
import os.log
#if canImport(CocoaLumberjackSwift)
import CocoaLumberjackSwift

public var ddLogLevel: DDLogLevel = {
  #if DEBUG
  return .debug
  #else
  return .info
  #endif
}()

private var appLoggingConfigured = false
private func setupCocoaLumberjackAppLogging() {
  if appLoggingConfigured { return }
  appLoggingConfigured = true

  DDLog.add(DDOSLogger.sharedInstance)

  if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.teachgatedesk.develentcorp") {
    let logsDir = containerURL.appendingPathComponent("Logs/App").path
    try? FileManager.default.createDirectory(atPath: logsDir, withIntermediateDirectories: true, attributes: nil)
    let logFileManager = DDLogFileManagerDefault(logsDirectory: logsDir)
    let fileLogger = DDFileLogger(logFileManager: logFileManager)
    fileLogger.rollingFrequency = 60 * 60 * 24 // 24 hours
    fileLogger.maximumFileSize = 5 * 1024 * 1024 // 5 MB
    fileLogger.logFileManager.maximumNumberOfLogFiles = 7
    fileLogger.logFileManager.logFilesDiskQuota = 30 * 1024 * 1024 // 30 MB
    DDLog.add(fileLogger)

    DDLogInfo("CocoaLumberjack initialized for app. Logs at \(logsDir)")
  } else {
    DDLogWarn("App Group container URL is nil; app file logging disabled")
  }
}
#else
public enum DDLogLevel { case debug, info }
public var ddLogLevel: DDLogLevel = {
  #if DEBUG
  return .debug
  #else
  return .info
  #endif
}()

private func setupCocoaLumberjackAppLogging() {}

private let OutlineVpnProdLogger = OSLog(subsystem: "com.teachgatedesk.develentcorp", category: "OutlineVpnProduction-DD")
@inline(__always) func DDLogDebug(_ message: String) {
  os_log("%{public}@", log: OutlineVpnProdLogger, type: .debug, message)
}
@inline(__always) func DDLogWarn(_ message: String) {
  os_log("%{public}@", log: OutlineVpnProdLogger, type: .error, message)
}
@inline(__always) func DDLogError(_ message: String) {
  os_log("%{public}@", log: OutlineVpnProdLogger, type: .error, message)
}
#endif

// Manages the system's VPN tunnel through the VpnExtension process.
/**
 Local error type mirroring OutlineError to avoid tight compile-time coupling while preserving messages.
 This conforms to LocalizedError so the React Native layer can surface readable messages.
*/
enum OutlineProdError: Error, LocalizedError {
  case vpnPermissionNotGranted(cause: Error)
  case setupSystemVPNFailed(cause: Error)
  case internalError(message: String)
  case detailedJsonError(code: String, json: String)

  var errorDescription: String? {
    switch self {
    case .vpnPermissionNotGranted(let cause):
      return "VPN permission not granted: \(cause.localizedDescription)"
    case .setupSystemVPNFailed(let cause):
      return "Failed to setup system VPN: \(cause.localizedDescription)"
    case .internalError(let message):
      return "Internal error: \(message)"
    case .detailedJsonError(let code, let json):
      return "Detailed error (code: \(code)): \(json)"
    }
  }
}

@objcMembers
public class OutlineVpnProduction: NSObject {
  public static let shared = OutlineVpnProduction()
  private static let kVpnExtensionBundleId = "\(Bundle.main.bundleIdentifier!).TeachGateVPN"

  public typealias VpnStatusObserver = (NEVPNStatus, String) -> Void

  private var vpnStatusObserver: VpnStatusObserver?

  private enum Action {
    static let start = "start"
    static let restart = "restart"
    static let stop = "stop"
    static let getTunnelId = "getTunnelId"
  }

  private enum ConfigKey {
    static let tunnelId = "id"
    static let transport = "transport"
  }

  override private init() {
    super.init()
    setupCocoaLumberjackAppLogging()
    // Register observer for VPN changes.
    // Remove self to guard against receiving duplicate notifications due to page reloads.
    NotificationCenter.default.removeObserver(self, name: .NEVPNStatusDidChange, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(self.vpnStatusChanged),
                                           name: .NEVPNStatusDidChange, object: nil)
  }

  // MARK: - Interface

  /** Starts a VPN tunnel as specified in the OutlineTunnel object. */
  public func start(
    _ tunnelId: String,
    named name: String?,
    withTransport transportConfig: String,
    autoConnect: Bool? = nil,
    onDemandRules: [[String: Any]]? = nil,
    connectivityCheck: [String: Any]? = nil
  ) async throws {
    if let manager = await getTunnelManager(), isActiveSession(manager.connection) {
      DDLogDebug("Stopping active session before starting new one")
      await stopSession(manager)
    }

    let manager: NETunnelProviderManager
    do {
      manager = try await setupVpn(
        withId: tunnelId,
        named: name ?? "Outline Server",
        withTransport: transportConfig,
        autoConnect: autoConnect,
        onDemandRules: onDemandRules,
        connectivityCheck: connectivityCheck
      )
    } catch {
      DDLogError("Failed to setup VPN: \(error.localizedDescription)")
      throw OutlineProdError.vpnPermissionNotGranted(cause: error)
    }
    let session = manager.connection as! NETunnelProviderSession

    // Register observer for start process completion.
    class TokenHolder {
      var token: NSObjectProtocol?
    }
    let tokenHolder = TokenHolder()
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      tokenHolder.token = NotificationCenter.default.addObserver(forName: .NEVPNStatusDidChange, object: manager.connection, queue: nil) { notification in
        // The notification object is always the session, so we can rely on that to not be nil.
        guard let connection = notification.object as? NETunnelProviderSession else {
          DDLogDebug("Failed to cast notification.object to NETunnelProviderSession")
          return
        }
        
        let status = connection.status
        DDLogDebug("OutlineVpn.start got status \(String(describing: status)), notification: \(String(describing: notification))")
        // The observer may be triggered multiple times, but we only remove it when we reach an end state.
        // A successful connection will go through .connecting -> .disconnected
        // A failed connection will go through .connecting -> .disconnecting -> .disconnected
        // An .invalid event may happen if the configuration is modified and ends in an invalid state.
        if status == .connected || status == .disconnected || status == .invalid {
          DDLogDebug("Tunnel start done.")
          if let token = tokenHolder.token {
            NotificationCenter.default.removeObserver(token, name: .NEVPNStatusDidChange, object: connection)
          }
          continuation.resume()
        }
      }
    }

    // Start the session.
    do {
      DDLogDebug("Calling NETunnelProviderSession.startTunnel([:])")
      try session.startTunnel(options: [:])
      DDLogDebug("NETunnelProviderSession.startTunnel() returned")
    } catch {
      DDLogError("Failed to start VPN: \(error.localizedDescription)")
      throw OutlineProdError.setupSystemVPNFailed(cause: error)
    }

    // Start observation completed.

    switch manager.connection.status {
    case .connected:
      break
    case .disconnected, .invalid:
      guard let err = await fetchExtensionLastDisconnectError(session) else {
        throw OutlineProdError.internalError(message: "unexpected nil disconnect error")
      }
      throw err
    default:
      // This shouldn't happen.
      throw OutlineProdError.internalError(message: "unexpected connection status")
    }

    // Apply on-demand settings based on autoConnect / onDemandRules
    do { try await manager.loadFromPreferences() }
    catch {
      DDLogWarn("OutlineVpn.start: Failed to reload preferences: \(error.localizedDescription)")
    }

    var resolvedRules: [NEOnDemandRule]? = nil
    if let rulesConfig = onDemandRules, !rulesConfig.isEmpty {
      resolvedRules = parseOnDemandRules(rulesConfig)
    }

    if resolvedRules == nil || (resolvedRules?.isEmpty ?? true) {
      if let auto = autoConnect {
        if auto {
          let connectRule = NEOnDemandRuleConnect()
          connectRule.interfaceTypeMatch = .any
          resolvedRules = [connectRule]
        } else {
          resolvedRules = []
        }
      } else {
        // Default to enabling connect-on-demand to preserve previous behavior
        let connectRule = NEOnDemandRuleConnect()
        connectRule.interfaceTypeMatch = .any
        resolvedRules = [connectRule]
      }
    }

    if let rules = resolvedRules, !rules.isEmpty {
      manager.onDemandRules = rules
      manager.isOnDemandEnabled = true
    } else {
      manager.onDemandRules = nil
      manager.isOnDemandEnabled = false
    }

    do { try await manager.saveToPreferences() }
    catch {
      DDLogWarn("OutlineVpn.start: Failed to save on-demand preference change: \(error.localizedDescription)")
    }
  }

  /** Tears down the VPN if the tunnel with id |tunnelId| is active. */
  public func stop(_ tunnelId: String) async {
    guard let manager = await getTunnelManager(),
          getTunnelId(forManager: manager) == tunnelId,
          isActiveSession(manager.connection) else {
      DDLogWarn("Trying to stop tunnel \(tunnelId) that is not running")
      return
    }
    await stopSession(manager)
  }

  /** Calls |observer| when the VPN's status changes. */
  public func onVpnStatusChange(_ observer: @escaping(VpnStatusObserver)) {
    vpnStatusObserver = observer
  }

  
  /** Returns whether |tunnelId| is actively proxying through the VPN. */
  public func isActive(_ tunnelId: String?) async -> Bool {
    guard tunnelId != nil, let manager = await getTunnelManager() else {
      return false
    }
    return getTunnelId(forManager: manager) == tunnelId && isActiveSession(manager.connection)
  }

  // MARK: - Helpers

  public func stopActiveVpn() async {
    if let manager = await getTunnelManager() {
      await stopSession(manager)
    }
  }

  // Adds a VPN configuration to the user preferences if no Outline profile is present. Otherwise
  // enables the existing configuration.
  private func setupVpn(
    withId id: String,
    named name: String,
    withTransport transportConfig: String,
    autoConnect: Bool? = nil,
    onDemandRules: [[String: Any]]? = nil,
    connectivityCheck: [String: Any]? = nil
  ) async throws -> NETunnelProviderManager {
    let managers = try await NETunnelProviderManager.loadAllFromPreferences()
    var manager: NETunnelProviderManager!
    if managers.count > 0 {
      manager = managers.first
    } else {
      manager = NETunnelProviderManager()
    }

    manager.localizedDescription = name
    // Make sure on-demand is disabled here; we'll set it after start as needed.
    manager.onDemandRules = nil

    // Configure the protocol.
    let config = NETunnelProviderProtocol()
    // TODO(fortuna): set to something meaningful if we can.
    config.serverAddress = "Outline"
    config.providerBundleIdentifier = OutlineVpnProduction.kVpnExtensionBundleId

    var provider: [String: Any] = [
      ConfigKey.tunnelId: id,
      ConfigKey.transport: transportConfig
    ]
    if let auto = autoConnect {
      provider["autoConnect"] = auto
    }
    if let rules = onDemandRules {
      provider["onDemandRules"] = rules
    }
    if let cc = connectivityCheck {
      provider["connectivityCheck"] = cc
    }
    config.providerConfiguration = provider
    manager.protocolConfiguration = config

    // A VPN configuration must be enabled before it can be used to bring up a VPN tunnel.
    manager.isEnabled = true

    try await manager.saveToPreferences()
    // Workaround for https://forums.developer.apple.com/thread/25928
    try await manager.loadFromPreferences()
    return manager
  }

  // Receives NEVPNStatusDidChange notifications. Calls onTunnelStatusChange for the active
  // tunnel.
  func vpnStatusChanged(notification: NSNotification) {
    DDLogDebug("OutlineVpn.vpnStatusChanged: \(String(describing: notification))")
    guard let session = notification.object as? NETunnelProviderSession else {
      DDLogDebug("Bad session in OutlineVpn.vpnStatusChanged")
      return
    }
    guard let manager = session.manager as? NETunnelProviderManager else {
      // For some reason we get spurious notifications with connecting and disconnecting states
      DDLogDebug("Bad manager in OutlineVpn.vpnStatusChanged session=\(String(describing:session)) status=\(String(describing: session.status))")
      return
    }
    guard let protoConfig = manager.protocolConfiguration as? NETunnelProviderProtocol,
          let tunnelId = protoConfig.providerConfiguration?["id"] as? String else {
      DDLogWarn("Bad VPN Config: \(String(describing: session.manager.protocolConfiguration))")
      return
    }
    DDLogDebug("OutlineVpn received status change for \(tunnelId): \(String(describing: session.status))")
    if isActiveSession(session) {
      Task {
        var enable = true
        if let proto = manager.protocolConfiguration as? NETunnelProviderProtocol {
          let pc = proto.providerConfiguration
          let auto = pc?["autoConnect"] as? Bool
          let rulesCfg = pc?["onDemandRules"] as? [[String: Any]]
          if let rulesArray = rulesCfg {
            enable = !rulesArray.isEmpty
          } else if let a = auto {
            enable = a
          } else {
            enable = true
          }
        }
        await setConnectVpnOnDemand(manager, enable)
      }
    }
    self.vpnStatusObserver?(session.status, tunnelId)
  }
}

// Retrieves the application's tunnel provider manager from the VPN preferences.
private func getTunnelManager() async -> NETunnelProviderManager? {
  do {
    let managers: [NETunnelProviderManager] = try await NETunnelProviderManager.loadAllFromPreferences()
    guard managers.count > 0 else {
      DDLogDebug("OutlineVpn.getTunnelManager: No managers found")
      return nil
    }
    return managers.first
  } catch {
    DDLogError("Failed to get tunnel manager: \(error.localizedDescription)")
    return nil
  }
}

private func getTunnelId(forManager manager:NETunnelProviderManager?) -> String? {
  let protoConfig = manager?.protocolConfiguration as? NETunnelProviderProtocol
  return protoConfig?.providerConfiguration?["id"] as? String
}

private func isActiveSession(_ session: NEVPNConnection?) -> Bool {
  let vpnStatus = session?.status
  return vpnStatus == .connected || vpnStatus == .connecting || vpnStatus == .reasserting
}

private func stopSession(_ manager:NETunnelProviderManager) async {
  do {
    try await manager.loadFromPreferences()
    await setConnectVpnOnDemand(manager, false) // Disable on demand so the VPN does not connect automatically.
    manager.connection.stopVPNTunnel()
    // Wait for stop to be completed.
    class TokenHolder {
      var token: NSObjectProtocol?
    }
    let tokenHolder = TokenHolder()
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      tokenHolder.token = NotificationCenter.default.addObserver(forName: .NEVPNStatusDidChange, object: manager.connection, queue: nil) { notification in
        if manager.connection.status == .disconnected {
          DDLogDebug("Tunnel stopped. Ready to start again.")
          if let token = tokenHolder.token {
            NotificationCenter.default.removeObserver(token, name: .NEVPNStatusDidChange, object: manager.connection)
          }
          continuation.resume()
        }
      }
    }
  } catch {
    DDLogWarn("Failed to stop VPN")
  }
}

private func setConnectVpnOnDemand(_ manager: NETunnelProviderManager?, _ enabled: Bool) async {
  do {
    try await manager?.loadFromPreferences()
    manager?.isOnDemandEnabled = enabled
    try await manager?.saveToPreferences()
  } catch {
    DDLogError("Failed to set VPN on demand to \(enabled): \(error)")
    return
  }
}

// Build NEOnDemandRule array from Outline-Apps style dictionaries.
private func parseOnDemandRules(_ configRules: [[String: Any]]) -> [NEOnDemandRule] {
  var rules: [NEOnDemandRule] = []
  for item in configRules {
    guard let rawType = (item["type"] as? String)?.lowercased() else { continue }
    switch rawType {
    case "connect":
      let r = NEOnDemandRuleConnect()
      if let iface = mapInterfaceType(item["interfaceTypeMatch"]) {
        r.interfaceTypeMatch = iface
      }
      rules.append(r)
    case "disconnect":
      let r = NEOnDemandRuleDisconnect()
      if let iface = mapInterfaceType(item["interfaceTypeMatch"]) {
        r.interfaceTypeMatch = iface
      }
      rules.append(r)
    case "ignore":
      let r = NEOnDemandRuleIgnore()
      if let iface = mapInterfaceType(item["interfaceTypeMatch"]) {
        r.interfaceTypeMatch = iface
      }
      rules.append(r)
    case "evaluate":
      let r = NEOnDemandRuleEvaluateConnection()
      if let iface = mapInterfaceType(item["interfaceTypeMatch"]) {
        r.interfaceTypeMatch = iface
      }
      var evalRules: [NEEvaluateConnectionRule] = []
      if let crs = item["connectionRules"] as? [[String: Any]] {
        for cr in crs {
          let domains = cr["domains"] as? [String] ?? []
          let actionStr = (cr["action"] as? String)?.lowercased()
          let action: NEEvaluateConnectionRuleAction = (actionStr == "neverconnect" || actionStr == "never_connect" || actionStr == "ignore") ? .neverConnect : .connectIfNeeded
          let eval = NEEvaluateConnectionRule(matchDomains: domains, andAction: action)
          if let probe = cr["probeURL"] as? String, let url = URL(string: probe) {
            eval.probeURL = url
          }
          evalRules.append(eval)
        }
      } else {
        // Support a simplified form on a single rule level.
        let domains = item["domains"] as? [String] ?? []
        let actionStr = (item["action"] as? String)?.lowercased()
        let action: NEEvaluateConnectionRuleAction = (actionStr == "neverconnect" || actionStr == "never_connect" || actionStr == "ignore") ? .neverConnect : .connectIfNeeded
        let eval = NEEvaluateConnectionRule(matchDomains: domains, andAction: action)
        if let probe = item["probeURL"] as? String, let url = URL(string: probe) {
          eval.probeURL = url
        }
        evalRules.append(eval)
      }
      r.connectionRules = evalRules
      rules.append(r)
    default:
      continue
    }
  }
  return rules
}

private func mapInterfaceType(_ value: Any?) -> NEOnDemandRuleInterfaceType? {
  guard let s = (value as? String)?.lowercased() else { return nil }
  switch s {
  // On macOS, cellular is unavailable; to keep behavior consistent and avoid
  // platform-specific enum cases, coalesce all to `.any` when requested.
  case "any", "*", "wifi", "wi-fi", "wlan", "ethernet", "lan":
    return .any
  default:
    return nil
  }
}


// MARK: - Fetch last disconnect error

// TODO: Remove this code once we only support newer systems (macOS 13.0+, iOS 16.0+)
// mimics fetchLastDisconnectErrorWithCompletionHandler on older systems
// See: "fetch last disconnect error" section in the VPN extension code.

private enum ExtensionIPC {
  static let fetchLastDetailedJsonError = "fetchLastDisconnectDetailedJsonError"
}

/// Keep it in sync with the data type defined in PacketTunnelProvider.Swift
/// Also keep in mind that we will always use PropertyListEncoder and PropertyListDecoder to marshal this data.
private struct LastErrorIPCData: Decodable {
  let errorCode: String
  let errorJson: String
}

// Fetches the most recent error that caused the VPN extension to disconnect.
// If no error, it returns nil. Otherwise, it returns a description of the error.
private func fetchExtensionLastDisconnectError(_ session: NETunnelProviderSession) async -> Error? {
  do {
    guard let rpcNameData = ExtensionIPC.fetchLastDetailedJsonError.data(using: .utf8) else {
      return OutlineProdError.internalError(message: "IPC fetchLastDisconnectError failed")
    }
    return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Error?, Error>) in
      do {
        DDLogDebug("Calling Extension IPC: \(ExtensionIPC.fetchLastDetailedJsonError)")
        try session.sendProviderMessage(rpcNameData) { data in
          guard let response = data else {
            DDLogDebug("Extension IPC returned with nil error")
            return continuation.resume(returning: nil)
          }
          do {
            let lastError = try PropertyListDecoder().decode(LastErrorIPCData.self, from: response)
            DDLogDebug("Extension IPC returned with \(lastError)")
            continuation.resume(returning: OutlineProdError.detailedJsonError(code: lastError.errorCode,
                                                                              json: lastError.errorJson))
          } catch {
            continuation.resume(throwing: error)
          }
        }
      } catch {
        continuation.resume(throwing: error)
      }
    }
  } catch {
    DDLogError("Failed to invoke VPN Extension IPC: \(error)")
    return OutlineProdError.internalError(
      message: "IPC fetchLastDisconnectError failed: \(error.localizedDescription)"
    )
  }
}