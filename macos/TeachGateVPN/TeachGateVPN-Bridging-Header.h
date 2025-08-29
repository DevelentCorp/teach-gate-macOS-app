#pragma once
#pragma once
//
//  TeachGateVPN-Bridging-Header.h
//  TeachGateVPN
//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import <NetworkExtension/NetworkExtension.h>

// Expose Tun2socks and Outline gobind ObjC APIs to Swift
// These headers are inside the Tun2socks.framework that is part of the target.
#import <Tun2socks/Tun2socks.objc.h>
#import <Tun2socks/Outline.objc.h>