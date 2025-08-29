import Foundation

enum VPNProviderBundleResolver {
  static func resolve() -> String? {
    // 1) Explicit app Info.plist override
    if let dict = Bundle.main.infoDictionary,
       let explicit = dict["VPNProviderBundleIdentifier"] as? String,
       !explicit.isEmpty {
      return explicit
    }

    // 2) Inspect embedded appex bundles
    if let pluginsURL = Bundle.main.builtInPlugInsURL,
       let contents = try? FileManager.default.contentsOfDirectory(at: pluginsURL, includingPropertiesForKeys: nil) {
      for url in contents where url.pathExtension == "appex" {
        let infoURL = url.appendingPathComponent("Contents/Info.plist")
        if let data = try? Data(contentsOf: infoURL),
           let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
           let extDict = (plist["NSExtension"] as? [String: Any]),
           let point = extDict["NSExtensionPointIdentifier"] as? String,
           point == "com.apple.networkextension.packet-tunnel",
           let bid = plist["CFBundleIdentifier"] as? String,
           !bid.isEmpty {
          return bid
        }
      }
    }
    return nil
  }
}