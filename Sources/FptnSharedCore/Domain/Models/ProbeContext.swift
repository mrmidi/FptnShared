/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation

/// Represents the network classification of the client connection.
/// Used to separate cache records (e.g. latency metrics on cellular and Wi-Fi are stored separately).
public enum NetworkClass: String, Sendable, Codable, Hashable {
    case wifi
    case cellular
    case wired
    case unknown
}

/// Holds metadata about the current network status and connection parameters.
/// This context is passed to the racing probes so they can log metrics and segment cache keys appropriately.
public struct ProbeContext: Sendable, Hashable, Codable {
    public let networkClass: NetworkClass
    public let sni: String
    public let censorshipStrategy: CensorshipStrategy
    public let ipv6Available: Bool
    public let tokenConfigurationID: String

    public init(
        networkClass: NetworkClass,
        sni: String,
        censorshipStrategy: CensorshipStrategy,
        ipv6Available: Bool,
        tokenConfigurationID: String
    ) {
        self.networkClass = networkClass
        self.sni = sni
        self.censorshipStrategy = censorshipStrategy
        self.ipv6Available = ipv6Available
        self.tokenConfigurationID = tokenConfigurationID
    }
}
