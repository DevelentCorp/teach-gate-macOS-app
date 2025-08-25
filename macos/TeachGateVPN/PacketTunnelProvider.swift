// Copyright 2024 Teach Gate
//
// Hybrid Swift side for the PacketTunnelProvider, adapted from Outline production.
// Provides SwiftBridge utilities used by the Objective-C PacketTunnelProvider.m
// and helper networking/routing utilities. This file intentionally does NOT
// define a PacketTunnelProvider class; the provider is implemented in Objective-C.

import Foundation
import NetworkExtension
import Darwin

@objcMembers
public class SwiftBridge: NSObject {

  // MARK: - Network Settings

  /// Returns the NEPacketTunnelNetworkSettings configured similarly to Outline production.
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

  // MARK: - NSError helpers (Outline-compatible facade)

  /// Creates an NSError similar to OutlineError.internalError(message:).
  public static func newInternalOutlineError(message: String) -> NSError {
    return outlineNSError(code: "internalError", message: message)
  }

  /// Creates an NSError similar to OutlineError.invalidConfig(message:).
  public static func newInvalidConfigOutlineError(message: String) -> NSError {
    return outlineNSError(code: "invalidConfig", message: message)
  }

  /// Wraps/normalizes any NSError into an Outline-style NSError with JSON details.
  public static func newOutlineErrorFrom(nsError: Error?) -> NSError? {
    guard let err = nsError else { return nil }
    // If it's already NSError, propagate but ensure domain info JSON is present
    let nserr = err as NSError
    if nserr.domain == outlineErrorDomain {
      return nserr
    }
    // Map foreign error into Outline-style NSError
    return outlineNSError(code: outlineCodeFor(error: nserr), message: nserr.localizedDescription)
  }

  // MARK: - Persist last disconnect error (IPC for older systems)

  /// TODO: Remove this code once only newer systems (macOS 13.0+, iOS 16.0+) are supported.
  public static func saveLastError(nsError: Error?) {
    guard let err = nsError else {
      UserDefaults.standard.removeObject(forKey: lastDisconnectErrorPersistenceKey)
      return
    }
    let outlineErrCode = outlineCodeFor(error: err as NSError)
    let persistObj = LastErrorIPCData(
      errorCode: outlineErrCode,
      errorJson: marshalErrorJson(error: err)
    )
    do {
      let encodedObj = try PropertyListEncoder().encode(persistObj)
      UserDefaults.standard.setValue(encodedObj, forKey: lastDisconnectErrorPersistenceKey)
    } catch {
      NSLog("failed to persist lastDisconnectError \(persistObj): \(error.localizedDescription)")
    }
  }

  /// Returns PropertyList-encoded LastErrorIPCData for IPC response.
  public static func loadLastErrorToIPCResponse() -> NSData? {
    return UserDefaults.standard.data(forKey: lastDisconnectErrorPersistenceKey) as NSData?
  }

  // MARK: - Internal helpers

  private static let outlineErrorDomain = "OutlineError"

  /// Builds an NSError following Outline error expectations with JSON details in userInfo.
  private static func outlineNSError(code: String, message: String) -> NSError {
    let json = ["message": message, "code": code]
    let jsonData = try? JSONSerialization.data(withJSONObject: json, options: [])
    let jsonString = jsonData.flatMap { String(data: $0, encoding: .utf8) } ?? "{\"message\":\"\(message)\"}"
    return NSError(
      domain: outlineErrorDomain,
      code: 1,
      userInfo: [
        NSLocalizedDescriptionKey: message,
        "code": code,
        "json": jsonString
      ]
    )
  }

  /// Best-effort error code mapping compatible with Outline expectations.
  private static func outlineCodeFor(error: NSError) -> String {
    if let explicit = (error.userInfo["code"] as? String), !explicit.isEmpty {
      return explicit
    }
    // Minimal mapping; extend as needed.
    switch (error.domain, error.code) {
      case (NSURLErrorDomain, NSURLErrorTimedOut): return "serverUnreachable"
      case (NSURLErrorDomain, NSURLErrorCannotFindHost): return "serverUnreachable"
      default: return "internalError"
    }
  }

  /// Marshals any Error into a JSON string used by the app to display details.
  private static func marshalErrorJson(error: Error) -> String {
    let nserr = error as NSError
    let dict: [String: Any] = [
      "localizedDescription": nserr.localizedDescription,
      "domain": nserr.domain,
      "code": nserr.code
    ]
    if let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
       let str = String(data: data, encoding: .utf8) {
      return str
    }
    return "{\"localizedDescription\":\"\(nserr.localizedDescription)\"}"
  }
}

// MARK: - Models and helpers adapted from Outline production Swift

// Represents an IP subnetwork.
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
    NSLog("Failed to retrieve network interface addresses")
    return addresses
  }

  var interface = interfaces
  while interface != nil {
    if let addr = interface?.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) {
      let sa = UnsafeRawPointer(addr).assumingMemoryBound(to: sockaddr_in.self)
      let ipString = withUnsafePointer(to: sa.pointee.sin_addr) { ptr in
        String(cString: inet_ntoa(ptr.pointee))
      }
      addresses.append(ipString)
    }
    interface = interface?.pointee.ifa_next
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

// MARK: - fetch last disconnect error (IPC payload)

let lastDisconnectErrorPersistenceKey = "lastDisconnectError"

private struct LastErrorIPCData: Codable {
  let errorCode: String
  let errorJson: String
}