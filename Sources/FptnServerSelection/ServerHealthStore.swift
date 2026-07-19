/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
import FptnSharedCore

public struct ServerHealthKey: Hashable, Codable, Sendable {
    public let serverID: String
    public let networkClass: NetworkClass
    public let sni: String
    public let censorshipStrategy: CensorshipStrategy
    public let ipv6Available: Bool
    public let tokenConfigurationID: String

    public init(
        serverID: String,
        networkClass: NetworkClass,
        sni: String,
        censorshipStrategy: CensorshipStrategy,
        ipv6Available: Bool,
        tokenConfigurationID: String
    ) {
        self.serverID = serverID
        self.networkClass = networkClass
        self.sni = sni
        self.censorshipStrategy = censorshipStrategy
        self.ipv6Available = ipv6Available
        self.tokenConfigurationID = tokenConfigurationID
    }
}

public struct ServerHealthRecord: Sendable, Codable {
    public let key: ServerHealthKey
    public let ewmaLatencyMs: Double?
    public let consecutiveFailures: Int
    public let lastSuccessAt: Date?
    public let lastFailureAt: Date?
    public let cooldownUntil: Date?
    public let schemaVersion: Int

    public init(
        key: ServerHealthKey,
        ewmaLatencyMs: Double? = nil,
        consecutiveFailures: Int = 0,
        lastSuccessAt: Date? = nil,
        lastFailureAt: Date? = nil,
        cooldownUntil: Date? = nil,
        schemaVersion: Int = 1
    ) {
        self.key = key
        self.ewmaLatencyMs = ewmaLatencyMs
        self.consecutiveFailures = consecutiveFailures
        self.lastSuccessAt = lastSuccessAt
        self.lastFailureAt = lastFailureAt
        self.cooldownUntil = cooldownUntil
        self.schemaVersion = schemaVersion
    }
}

public struct ServerHealthUpdate: Sendable {
    public let key: ServerHealthKey
    public let observation: ServerHealthObservation

    public init(key: ServerHealthKey, observation: ServerHealthObservation) {
        self.key = key
        self.observation = observation
    }
}

public protocol ServerHealthStore: Sendable {
    func load(for keys: [ServerHealthKey]) async throws -> [ServerHealthKey: ServerHealthRecord]
    func apply(_ updates: [ServerHealthUpdate]) async throws
}
