/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
import FptnSharedCore

public enum TunnelStartupPayloadError: Error, Equatable, Sendable {
    case payloadTooLarge
    case unsupportedSchemaVersion(Int)
    case invalidField(String)
}

public struct TunnelStartupConfigurationV1: Codable, Sendable, Equatable {
    public static let supportedSchemaVersion = 1
    public static let maximumEncodedSize = 65536 // 64 KiB

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
    public let censorshipStrategy: CensorshipStrategy
    public let logLevel: SharedLogLevel
    public let websocketIdleTimeoutSeconds: Int
    public let customDnsIPv4: String?
    public let perAppMode: PerAppTunnelMode
    public let allowedBundleIDs: [String]

    public init(
        schemaVersion: Int = 1,
        episodeID: UUID,
        recoveryPolicy: TunnelRecoveryPolicy,
        serverHost: String,
        serverPort: Int,
        accessToken: String,
        dnsIPv4: String,
        dnsIPv6: String? = nil,
        sni: String,
        md5Fingerprint: String,
        censorshipStrategy: CensorshipStrategy,
        logLevel: SharedLogLevel = .warning,
        websocketIdleTimeoutSeconds: Int = 30,
        customDnsIPv4: String? = nil,
        perAppMode: PerAppTunnelMode = .disabled,
        allowedBundleIDs: [String] = []
    ) throws {
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
        self.logLevel = logLevel
        self.websocketIdleTimeoutSeconds = websocketIdleTimeoutSeconds
        self.customDnsIPv4 = customDnsIPv4
        self.perAppMode = perAppMode
        self.allowedBundleIDs = allowedBundleIDs

        try validate()
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        guard version == Self.supportedSchemaVersion else {
            throw TunnelStartupPayloadError.unsupportedSchemaVersion(version)
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
        
        let stratRaw = try container.decodeIfPresent(String.self, forKey: .censorshipStrategy) ?? ""
        self.censorshipStrategy = CensorshipStrategy(storedValue: stratRaw)
        
        self.logLevel = try container.decodeIfPresent(SharedLogLevel.self, forKey: .logLevel) ?? .warning
        self.websocketIdleTimeoutSeconds = try container.decodeIfPresent(Int.self, forKey: .websocketIdleTimeoutSeconds) ?? 30
        self.customDnsIPv4 = try container.decodeIfPresent(String.self, forKey: .customDnsIPv4)
        self.perAppMode = try container.decodeIfPresent(PerAppTunnelMode.self, forKey: .perAppMode) ?? .disabled
        self.allowedBundleIDs = try container.decodeIfPresent([String].self, forKey: .allowedBundleIDs) ?? []

        try validate()
    }

    public func validate() throws {
        guard schemaVersion == Self.supportedSchemaVersion else {
            throw TunnelStartupPayloadError.unsupportedSchemaVersion(schemaVersion)
        }
        guard !serverHost.isEmpty, serverHost.utf8.count <= 255 else {
            throw TunnelStartupPayloadError.invalidField("serverHost")
        }
        guard serverPort >= 1 && serverPort <= 65535 else {
            throw TunnelStartupPayloadError.invalidField("serverPort")
        }
        guard !accessToken.isEmpty else {
            throw TunnelStartupPayloadError.invalidField("accessToken")
        }
        guard !dnsIPv4.isEmpty else {
            throw TunnelStartupPayloadError.invalidField("dnsIPv4")
        }
        guard !sni.isEmpty, sni.utf8.count <= 255 else {
            throw TunnelStartupPayloadError.invalidField("sni")
        }
        guard !md5Fingerprint.isEmpty, md5Fingerprint.utf8.count <= 256 else {
            throw TunnelStartupPayloadError.invalidField("md5Fingerprint")
        }
        guard websocketIdleTimeoutSeconds >= 1 && websocketIdleTimeoutSeconds <= 86400 else {
            throw TunnelStartupPayloadError.invalidField("websocketIdleTimeoutSeconds")
        }
        guard allowedBundleIDs.count <= 256 else {
            throw TunnelStartupPayloadError.invalidField("allowedBundleIDs count")
        }
        for bundleID in allowedBundleIDs {
            guard !bundleID.isEmpty, bundleID.utf8.count <= 255 else {
                throw TunnelStartupPayloadError.invalidField("allowedBundleID element")
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, episodeID, recoveryPolicy
        case serverHost, serverPort, accessToken, dnsIPv4, dnsIPv6
        case sni, md5Fingerprint, censorshipStrategy
        case logLevel, websocketIdleTimeoutSeconds, customDnsIPv4
        case perAppMode, allowedBundleIDs
    }
}

public typealias TunnelStartupConfiguration = TunnelStartupConfigurationV1
