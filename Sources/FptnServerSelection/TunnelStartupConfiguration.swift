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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        guard version == 1 else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported schema version: \(version)"
            )
        }
        self.schemaVersion = version
        self.episodeID = try container.decode(UUID.self, forKey: .episodeID)
        self.recoveryPolicy = try container.decodeIfPresent(TunnelRecoveryPolicy.self, forKey: .recoveryPolicy) ?? .none
        self.serverHost = try container.decode(String.self, forKey: .serverHost)
        self.serverPort = try container.decode(Int.self, forKey: .serverPort)
        self.accessToken = try container.decode(String.self, forKey: .accessToken)
        self.dnsIPv4 = try container.decode(String.self, forKey: .dnsIPv4)
        self.dnsIPv6 = try container.decodeIfPresent(String.self, forKey: .dnsIPv6)
        self.sni = try container.decode(String.self, forKey: .sni)
        self.md5Fingerprint = try container.decode(String.self, forKey: .md5Fingerprint)
        self.censorshipStrategy = try container.decode(String.self, forKey: .censorshipStrategy)
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, episodeID, recoveryPolicy
        case serverHost, serverPort, accessToken, dnsIPv4, dnsIPv6
        case sni, md5Fingerprint, censorshipStrategy
    }
}
