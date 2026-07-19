/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
import FptnSharedCore
import FptnServerSelection

public struct ManualConnectionRequest: Sendable {
    public let server: VPNServer
    public let credentials: Credentials
    public let bootstrapContext: BootstrapContext
    public let bootstrapPolicy: BootstrapPolicy

    public init(
        server: VPNServer,
        credentials: Credentials,
        bootstrapContext: BootstrapContext,
        bootstrapPolicy: BootstrapPolicy = .production
    ) {
        self.server = server
        self.credentials = credentials
        self.bootstrapContext = bootstrapContext
        self.bootstrapPolicy = bootstrapPolicy
    }
}

public struct AutoConnectionRequest: Sendable {
    public let servers: [VPNServer]
    public let credentials: Credentials
    public let bootstrapContext: BootstrapContext
    public let bootstrapPolicy: BootstrapPolicy

    public init(
        servers: [VPNServer],
        credentials: Credentials,
        bootstrapContext: BootstrapContext,
        bootstrapPolicy: BootstrapPolicy = .production
    ) {
        self.servers = servers
        self.credentials = credentials
        self.bootstrapContext = bootstrapContext
        self.bootstrapPolicy = bootstrapPolicy
    }
}

public enum ConnectionRequest: Sendable {
    case manual(ManualConnectionRequest)
    case auto(AutoConnectionRequest)
}
