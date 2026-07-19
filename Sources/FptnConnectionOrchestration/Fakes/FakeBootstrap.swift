/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
import FptnSharedCore

public final class FakeBootstrap: ServerBootstrapping, @unchecked Sendable {
    public var onBootstrap: ((VPNServer, Credentials) async -> ServerBootstrappingResult)?
    public private(set) var callCount = 0
    public private(set) var calledServers: [String] = []

    public init() {}

    public func bootstrap(
        server: VPNServer,
        credentials: Credentials,
        context: BootstrapContext,
        policy: BootstrapPolicy
    ) async -> ServerBootstrappingResult {
        callCount += 1
        calledServers.append(server.id)
        if let handler = onBootstrap {
            return await handler(server, credentials)
        }
        return .success(ServerBootstrapResult(
            server: server,
            accessToken: "fake-token-\(server.name)",
            dnsIPv4: "10.0.0.1",
            dnsIPv6: nil,
            metrics: ProbeMetrics(
                serverID: server.id,
                queuePosition: 0,
                queuedAtMs: 0, startedAtMs: 0, completedAtMs: 0,
                dnsMs: nil, tcpConnectMs: nil, fakeHandshakeMs: nil,
                tlsHandshakeMs: nil, loginHTTPMs: nil, bootstrapHTTPMs: nil,
                totalMs: 100,
                cancellationRequestedAtMs: nil, cancellationCompletedAtMs: nil,
                outcome: .success
            )
        ))
    }
}
