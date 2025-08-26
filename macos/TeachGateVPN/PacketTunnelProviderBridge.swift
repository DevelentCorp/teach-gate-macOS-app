import Foundation
import NetworkExtension

@objcMembers public class SwiftBridge: NSObject {
    @objc public class func getTunnelNetworkSettings() -> Any? {
        // Returning nil lets the Objective-C provider handle absent settings gracefully during tests.
        return nil
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