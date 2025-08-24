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

import Foundation

// OutlineError represents various error conditions that can occur in the Outline VPN system.
public enum OutlineError: Error {
    case vpnPermissionNotGranted(cause: Error)
    case setupSystemVPNFailed(cause: Error)
    case internalError(message: String)
    case detailedJsonError(code: String, json: String)
}

extension OutlineError: LocalizedError {
    public var errorDescription: String? {
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

extension OutlineError: CustomStringConvertible {
    public var description: String {
        return errorDescription ?? "Unknown OutlineError"
    }
}