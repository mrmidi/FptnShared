/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
import FptnSharedCore

public struct TunnelStartupConfiguration: Codable, Sendable {
    public let schemaVersion: Int
    public let episodeID: UUID
    public let recoveryPolicy: TunnelRecoveryPolicy
    public let serverHost: String
    public let serverPort: Int
    public let accessToken: String
    public let dnsIPv4: String
    public let dnsIPv6: String?
    public let sni: String
    public let md5Fingerprint: String
    public let censorshipStrategy: String

    public init(
        schemaVersion: Int = 1,
        episodeID: UUID,
        recoveryPolicy: TunnelRecoveryPolicy,
        serverHost: String,
        serverPort: Int,
        accessToken: String,
        dnsIPv4: String,
        dnsIPv6: String?,
        sni: String,
        md5Fingerprint: String,
        censorshipStrategy: String
    ) {
        self.schemaVersion = schemaVersion
        self.episodeID = episodeID
        self.recoveryPolicy = recoveryPolicy
        self.serverHost = serverHost
        self.serverPort = serverPort
        self.accessToken = accessToken
        self.dnsIPv4 = dnsIPv4
        self.dnsIPv6 = dnsIPv6
        self.sni = sni
        self.md5Fingerprint = md5Fingerprint
        self.censorshipStrategy = censorshipStrategy
    }
}
