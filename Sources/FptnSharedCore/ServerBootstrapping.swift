/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation

public struct BootstrapContext: Sendable, Hashable, Codable {
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

public struct BootstrapPolicy: Sendable, Codable {
    public let loginAttempts: Int
    public let dnsAttempts: Int
    public let stageTimeout: Duration
    public let candidateDeadline: Duration

    public init(
        loginAttempts: Int,
        dnsAttempts: Int,
        stageTimeout: Duration,
        candidateDeadline: Duration
    ) {
        self.loginAttempts = loginAttempts
        self.dnsAttempts = dnsAttempts
        self.stageTimeout = stageTimeout
        self.candidateDeadline = candidateDeadline
    }

    public static let production = BootstrapPolicy(
        loginAttempts: 1,
        dnsAttempts: 1,
        stageTimeout: .seconds(5),
        candidateDeadline: .seconds(8)
    )
}

public struct ServerBootstrapFailure: Sendable, Equatable {
    public let kind: String
    public let message: String

    public init(kind: String, message: String) {
        self.kind = kind
        self.message = message
    }
}

public enum ServerBootstrappingResult: Sendable {
    case success(ServerBootstrapResult)
    case failure(ServerBootstrapFailure)
}

public protocol ServerBootstrapping: Sendable {
    func bootstrap(
        server: VPNServer,
        credentials: Credentials,
        context: BootstrapContext,
        policy: BootstrapPolicy
    ) async -> ServerBootstrappingResult
}
