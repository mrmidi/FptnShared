/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
import FptnSharedCore
import FptnSharedTunnel
import FptnServerSelection

public struct AutoReselectionPolicy: Sendable, Codable, Equatable {
    public let maxReplacementAttempts: Int
    public let delaySeconds: Int

    public init(maxReplacementAttempts: Int = 3, delaySeconds: Int = 2) {
        self.maxReplacementAttempts = maxReplacementAttempts
        self.delaySeconds = delaySeconds
    }
}

public struct ManualConnectionRequest: Sendable {
    public let server: VPNServer
    public let credentials: Credentials
    public let bootstrapContext: BootstrapContext
    public let bootstrapPolicy: BootstrapPolicy
    public let tunnelRecoveryPolicy: TunnelRecoveryPolicy
    public let tunnelRuntimeOptions: TunnelRuntimeOptions

    public init(
        server: VPNServer,
        credentials: Credentials,
        bootstrapContext: BootstrapContext,
        bootstrapPolicy: BootstrapPolicy = .production,
        tunnelRecoveryPolicy: TunnelRecoveryPolicy = .none,
        tunnelRuntimeOptions: TunnelRuntimeOptions = TunnelRuntimeOptions()
    ) {
        self.server = server
        self.credentials = credentials
        self.bootstrapContext = bootstrapContext
        self.bootstrapPolicy = bootstrapPolicy
        self.tunnelRecoveryPolicy = tunnelRecoveryPolicy
        self.tunnelRuntimeOptions = tunnelRuntimeOptions
    }
}

public struct AutoConnectionRequest: Sendable {
    public let servers: [VPNServer]
    public let credentials: Credentials
    public let bootstrapContext: BootstrapContext
    public let bootstrapPolicy: BootstrapPolicy
    public let selectionPolicy: SelectionPolicy
    public let tunnelRecoveryPolicy: TunnelRecoveryPolicy
    public let reselectionPolicy: AutoReselectionPolicy
    public let tunnelRuntimeOptions: TunnelRuntimeOptions

    public init(
        servers: [VPNServer],
        credentials: Credentials,
        bootstrapContext: BootstrapContext,
        bootstrapPolicy: BootstrapPolicy = .production,
        selectionPolicy: SelectionPolicy = .production,
        tunnelRecoveryPolicy: TunnelRecoveryPolicy = .automatic(AutoTunnelRecoveryPolicy(sameServerAttempts: 2, reconnectDelaySeconds: 2)),
        reselectionPolicy: AutoReselectionPolicy = AutoReselectionPolicy(),
        tunnelRuntimeOptions: TunnelRuntimeOptions = TunnelRuntimeOptions()
    ) {
        self.servers = servers
        self.credentials = credentials
        self.bootstrapContext = bootstrapContext
        self.bootstrapPolicy = bootstrapPolicy
        self.selectionPolicy = selectionPolicy
        self.tunnelRecoveryPolicy = tunnelRecoveryPolicy
        self.reselectionPolicy = reselectionPolicy
        self.tunnelRuntimeOptions = tunnelRuntimeOptions
    }
}

public enum ConnectionRequest: Sendable {
    case manual(ManualConnectionRequest)
    case auto(AutoConnectionRequest)
}
