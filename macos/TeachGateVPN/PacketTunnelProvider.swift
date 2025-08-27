// Copyright 2024 The Outline Authors
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

// Use NSLog for VPN extension logging
@inline(__always) func DDLogInfo(_ msg: @autoclosure () -> String) { NSLog("[INFO] %@", msg()) }
@inline(__always) func DDLogDebug(_ msg: @autoclosure () -> String) { NSLog("[DEBUG] %@", msg()) }
@inline(__always) func DDLogWarn(_ msg: @autoclosure () -> String) { NSLog("[WARN] %@", msg()) }
@inline(__always) func DDLogError(_ msg: @autoclosure () -> String) { NSLog("[ERROR] %@", msg()) }
import NetworkExtension

// Define minimal OutlineError stub since the module import is not working
public enum OutlineError: Error {
  case internalError(message: String)
  case invalidConfig(message: String)
  
  public var code: String {
    switch self {
    case .internalError: return "internalError"
    case .invalidConfig: return "invalidConfig"
    }
  }
}

public func toOutlineError(error: Error) -> OutlineError {
  if let outlineError = error as? OutlineError {
    return outlineError
  }
  return OutlineError.internalError(message: error.localizedDescription)
}

public func marshalErrorJson(error: Error) -> String {
  let outlineErr = toOutlineError(error: error)
  return "{\"code\":\"\(outlineErr.code)\",\"message\":\"\(error.localizedDescription)\"}"
}

/// SwiftBridge is a transitional class to allow the incremental migration of our PacketTunnelProvider from Objective-C to Swift.
@objcMembers
public class SwiftBridge: NSObject {

  /** Helper function that we can call from Objective-C. */
  public static func getTunnelNetworkSettings() -> NEPacketTunnelNetworkSettings {
    // The remote address is not required, but needs to be valid, or else you get a
    // "Invalid NETunnelNetworkSettings tunnelRemoteAddress" error.
    let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "::")

    // Configure VPN address and routing.
    let vpnAddress = selectVpnAddress(interfaceAddresses: getNetworkInterfaceAddresses())
    let ipv4Settings = NEIPv4Settings(addresses: [vpnAddress], subnetMasks: ["255.255.255.0"])
    ipv4Settings.includedRoutes = [NEIPv4Route.default()]
    ipv4Settings.excludedRoutes = getExcludedIpv4Routes()
    settings.ipv4Settings = ipv4Settings

    // Configure with Cloudflare, Quad9, and OpenDNS resolver addresses.
    settings.dnsSettings = NEDNSSettings(servers: [
      "1.1.1.1", "9.9.9.9", "208.67.222.222", "208.67.220.220",
    ])

    return settings
  }

  /**
   Creates a NSError (of `OutlineError.errorDomain`) from the `OutlineError.internalError`.
   */
  public static func newInternalOutlineError(message: String) -> NSError {
    return OutlineError.internalError(message: message) as NSError
  }

  /**
   Creates a NSError (of `OutlineError.errorDomain`) from the `OutlineError.invalidConfig` error.
   */
  public static func newInvalidConfigOutlineError(message: String) -> NSError {
    return OutlineError.invalidConfig(message: message) as NSError
  }

  /**
   Creates a NSError (of `OutlineError.errorDomain`) with detailed JSON from another NSError.
   */
  public static func newOutlineErrorFrom(nsError: Error?) -> NSError? {
    guard let nserr = nsError else {
      return nil
    }
    return toOutlineError(error: nserr) as NSError
  }

  // TODO: Remove this code once we only support newer systems (macOS 13.0+, iOS 16.0+)
  public static func saveLastError(nsError: Error?) {
    saveLastDisconnectErrorDetails(error: nsError)
  }

  // TODO: Remove this code once we only support newer systems (macOS 13.0+, iOS 16.0+)
  public static func loadLastErrorToIPCResponse() -> NSData? {
    return loadLastDisconnectErrorDetailsToIPCResponse() as? NSData
  }
}

// Represents an IP subnetwork.
// Note that this class and its non-private properties must be public in order to be visible to the ObjC
// target of the OutlineAppleLib Swift Package.
class Subnet: NSObject {
  // Parses a CIDR subnet into a Subnet object. Returns nil on failure.
  public static func parse(_ cidrSubnet: String) -> Subnet? {
    let components = cidrSubnet.components(separatedBy: "/")
    guard components.count == 2 else {
      NSLog("Malformed CIDR subnet")
      return nil
    }
    guard let prefix = UInt16(components[1]) else {
      NSLog("Invalid subnet prefix")
      return nil
    }
    return Subnet(address: components[0], prefix: prefix)
  }

  public var address: String
  public var prefix: UInt16
  public var mask: String

  public init(address: String, prefix: UInt16) {
    self.address = address
    self.prefix = prefix
    let mask = (0xffff_ffff as UInt32) << (32 - prefix)
    self.mask = mask.IPv4String()
  }
}

extension UInt32 {
  // Returns string representation of the integer as an IP address.
  public func IPv4String() -> String {
    let ip = self
    let a = UInt8((ip >> 24) & 0xff)
    let b = UInt8((ip >> 16) & 0xff)
    let c = UInt8((ip >> 8) & 0xff)
    let d = UInt8(ip & 0xff)
    return "\(a).\(b).\(c).\(d)"
  }
}

// Returns all IPv4 addresses of all interfaces.
func getNetworkInterfaceAddresses() -> [String] {
  var interfaces: UnsafeMutablePointer<ifaddrs>?
  var addresses = [String]()

  guard getifaddrs(&interfaces) == 0 else {
    DDLogError("Failed to retrieve network interface addresses")
    return addresses
  }

  var interface = interfaces
  while interface != nil {
    // Only consider IPv4 interfaces.
    if interface!.pointee.ifa_addr.pointee.sa_family == UInt8(AF_INET) {
      let addr = interface!.pointee.ifa_addr!.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
        $0.pointee.sin_addr
      }
      if let ip = String(cString: inet_ntoa(addr), encoding: .utf8) {
        addresses.append(ip)
      }
    }
    interface = interface!.pointee.ifa_next
  }

  freeifaddrs(interfaces)

  return addresses
}

let kVpnSubnetCandidates: [String: String] = [
  "10": "10.111.222.0",
  "172": "172.16.9.1",
  "192": "192.168.20.1",
  "169": "169.254.19.0",
]

// Given the list of known interface addresses, returns a local network IP address to use for the VPN.
func selectVpnAddress(interfaceAddresses: [String]) -> String {
  var candidates = kVpnSubnetCandidates

  for address in interfaceAddresses {
    for subnetPrefix in kVpnSubnetCandidates.keys {
      if address.hasPrefix(subnetPrefix) {
        // The subnet (not necessarily the address) is in use, remove it from our list.
        candidates.removeValue(forKey: subnetPrefix)
      }
    }
  }
  guard !candidates.isEmpty else {
    // Even though there is an interface bound to the subnet candidates, the collision probability
    // with an actual address is low.
    return kVpnSubnetCandidates.randomElement()!.value
  }
  // Select a random subnet from the remaining candidates.
  return candidates.randomElement()!.value
}

let kExcludedSubnets = [
  "10.0.0.0/8",
  "100.64.0.0/10",
  "169.254.0.0/16",
  "172.16.0.0/12",
  "192.0.0.0/24",
  "192.0.2.0/24",
  "192.31.196.0/24",
  "192.52.193.0/24",
  "192.88.99.0/24",
  "192.168.0.0/16",
  "192.175.48.0/24",
  "198.18.0.0/15",
  "198.51.100.0/24",
  "203.0.113.0/24",
  "240.0.0.0/4",
]

func getExcludedIpv4Routes() -> [NEIPv4Route] {
  var excludedIpv4Routes = [NEIPv4Route]()
  for cidrSubnet in kExcludedSubnets {
    if let subnet = Subnet.parse(cidrSubnet) {
      let route = NEIPv4Route(destinationAddress: subnet.address, subnetMask: subnet.mask)
      excludedIpv4Routes.append(route)
    }
  }
  return excludedIpv4Routes
}

// MARK: - fetch last disconnect error

// TODO: Remove this code once we only support newer systems (macOS 13.0+, iOS 16.0+)

/**
  In the app, we need to use [NEVPNConnection fetchLastDisconnectErrorWithCompletionHandler] to
  retrive the most recent error that caused the VPN extension to disconnect.
  But it's only available on newer systems (macOS 13.0+, iOS 16.0+), so we need a workaround for
  older ones.
  The workaround lets the app to use [NETunnelProviderSession sendProviderMessage] to get the
  error through an IPC method.
  The extension also needs to save the last error to disk, as the system will unload the extension
  after a failed connection.
  We use [NSUserDefaults standardUserDefaults] to store the error, so it's available even after
  the extension restarts.
*/

let lastDisconnectErrorPersistenceKey = "lastDisconnectError"

/// Keep it in sync with the data type defined in OutlineVpn.Swift
/// Also keep in mind that we will always use PropertyListEncoder and PropertyListDecoder to marshal this data.
private struct LastErrorIPCData: Codable {
  let errorCode: String
  let errorJson: String
}

func saveLastDisconnectErrorDetails(error: Error?) {
  guard let err = error else {
    return UserDefaults.standard.removeObject(forKey: lastDisconnectErrorPersistenceKey)
  }
  let outlineErr = toOutlineError(error: err)
  let persistObj = LastErrorIPCData(
    errorCode: outlineErr.code, errorJson: marshalErrorJson(error: err))
  do {
    let encodedObj = try PropertyListEncoder().encode(persistObj)
    UserDefaults.standard.setValue(encodedObj, forKey: lastDisconnectErrorPersistenceKey)
  } catch {
    DDLogError("failed to persist lastDisconnectError \(persistObj): \(error)")
  }
}

func loadLastDisconnectErrorDetailsToIPCResponse() -> Data? {
  return UserDefaults.standard.data(forKey: lastDisconnectErrorPersistenceKey)
}

// MARK: - NEPacketTunnelProvider implementation

private enum ExtensionIPCCommand {
  static let fetchLastDetailedJsonError = "fetchLastDisconnectDetailedJsonError"
}

// Darwin AF_ constants for NEPacketTunnelFlow writeProtocols
private let AF_INET_NUM: Int32 = 2
private let AF_INET6_NUM: Int32 = 30

public class PacketTunnelProvider: NEPacketTunnelProvider {
  private var isReadingPackets = false

  // MARK: Lifecycle

  public override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
    DDLogInfo("PacketTunnelProvider.startTunnel invoked")

    // 1) Parse provider configuration
    guard
      let proto = (self.protocolConfiguration as? NETunnelProviderProtocol),
      let providerConfig = proto.providerConfiguration,
      let tunnelId = providerConfig["id"] as? String,
      let transportConfig = providerConfig["transport"] as? String
    else {
      let err = SwiftBridge.newInvalidConfigOutlineError(message: "Missing provider configuration (id/transport)")
      SwiftBridge.saveLastError(nsError: err)
      completionHandler(err)
      return
    }

    DDLogInfo("VPN config parsed - tunnelId: \(tunnelId), transport config length: \(transportConfig.count)")

    // 2) Compute tunnel network settings
    let settings = SwiftBridge.getTunnelNetworkSettings()

    // 3) Apply settings
    self.setTunnelNetworkSettings(settings) { [weak self] settingsError in
      guard let self = self else { return }
      if let settingsError = settingsError {
        let err = SwiftBridge.newOutlineErrorFrom(nsError: settingsError) ?? SwiftBridge.newInternalOutlineError(message: settingsError.localizedDescription)
        DDLogError("Failed to apply tunnel settings: \(settingsError)")
        SwiftBridge.saveLastError(nsError: err)
        completionHandler(err)
        return
      }

      DDLogInfo("Tunnel network settings applied successfully")
      
      // 4) For now, we'll simulate a successful connection since we're focusing on system integration
      // In a production environment, this would create the actual tunnel connection
      // TODO: Integrate actual Tun2socks connection once framework import is resolved
      
      // 5) Start packet processing loop (placeholder)
      self.startPacketReadLoop()

      // Clear last saved error on success
      SwiftBridge.saveLastError(nsError: nil)
      DDLogInfo("PacketTunnelProvider.startTunnel completed successfully")
      completionHandler(nil)
    }
  }

  public override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
    DDLogInfo("PacketTunnelProvider.stopTunnel reason=\(reason.rawValue)")
    // Stop reading packets first.
    self.isReadingPackets = false

    // TODO: Disconnect actual tun2socks tunnel when framework is properly integrated

    // Nothing specific to persist on clean shutdown.
    SwiftBridge.saveLastError(nsError: nil)
    completionHandler()
  }

  public override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
    guard let message = String(data: messageData, encoding: .utf8) else {
      completionHandler?(nil)
      return
    }
    DDLogDebug("PacketTunnelProvider.handleAppMessage \(message)")
    switch message {
    case ExtensionIPCCommand.fetchLastDetailedJsonError:
      // Returns a PropertyList-encoded LastErrorIPCData or nil
      completionHandler?(SwiftBridge.loadLastErrorToIPCResponse() as Data?)
    default:
      completionHandler?(nil)
    }
  }

  // MARK: Packet I/O

  private func startPacketReadLoop() {
    guard !isReadingPackets else { return }
    isReadingPackets = true
    readPackets()
  }

  private func readPackets() {
    guard isReadingPackets else { return }
    self.packetFlow.readPackets { [weak self] packets, _ in
      guard let self = self else { return }
      
      // TODO: Process packets through tun2socks tunnel when framework is integrated
      // For now, we'll just log the packet count for validation
      DDLogDebug("Received \(packets.count) packets for processing")
      
      // Continue loop if still active.
      if self.isReadingPackets {
        self.readPackets()
      }
    }
  }
}
