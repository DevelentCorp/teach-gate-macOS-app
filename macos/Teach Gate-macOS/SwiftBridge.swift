//
//  SwiftBridge.swift
//  Teach Gate-macOS
//
//  Swift bridging enabler for OutlineAppleLib package integration
//

import Foundation

// This minimal Swift file enables Xcode to generate bridging headers
// for the main app target which should contain OutlineVpn from linked SPM package

@objc public class SwiftBridge: NSObject {
    
    // Minimal class to trigger Swift bridging header generation
    @objc public static let shared = SwiftBridge()
    
    private override init() {
        super.init()
    }
}