import Foundation
import NetworkExtension

@objcMembers public class SwiftBridge: NSObject {
    @objc public class func getTunnelNetworkSettings() -> Any? {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "10.0.0.1")
        settings.ipv4Settings = NEIPv4Settings(addresses: ["10.0.0.2"], subnetMasks: ["255.255.255.0"])
        settings.ipv4Settings?.includedRoutes = [NEIPv4Route.default()]
        settings.dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "8.8.4.4"])
        return settings
    }

    @objc public class func newInvalidConfigOutlineErrorWithMessage(_ message: String) -> Any? {
        return NSError(domain: "com.teachgatedesk.develentcorp", code: 1001, userInfo: [NSLocalizedDescriptionKey: message])
    }

    @objc public class func newInternalOutlineErrorWithMessage(_ message: String) -> Any? {
        return NSError(domain: "com.teachgatedesk.develentcorp", code: 1002, userInfo: [NSLocalizedDescriptionKey: message])
    }

    @objc public class func newOutlineErrorFromNsError(_ error: NSError) -> Any? {
        return error
    }

    @objc public class func saveLastErrorWithNsError(_ err: NSError?) {
        guard let err = err else {
            UserDefaults.standard.removeObject(forKey: "TeachGateVPNLastError")
            return
        }
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: err, requiringSecureCoding: false) {
            UserDefaults.standard.set(data, forKey: "TeachGateVPNLastError")
        }
    }

    @objc public class func loadLastErrorToIPCResponse() -> Data? {
        return UserDefaults.standard.data(forKey: "TeachGateVPNLastError")
    }
}