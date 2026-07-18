/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation

/// In-memory non-Codable container to hold VPN authentication credentials.
/// By explicitly omitting `Codable`, we prevent credentials from being accidentally
/// serialized to logs, `UserDefaults`, or database storage.
public struct Credentials: Sendable {
    public let username: String
    public let password: String

    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}
