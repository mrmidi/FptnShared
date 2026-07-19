/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
#if !CLI_BUILD
import FptnSharedCore
#endif

public actor FakeServerBootstrapping: ServerBootstrapping {
    private var _onBootstrap: ((VPNServer, Credentials) async -> ServerBootstrapAttempt)?
    public private(set) var callCount = 0
    public private(set) var calledServers: [String] = []

    public init(onBootstrap: ((VPNServer, Credentials) async -> ServerBootstrapAttempt)? = nil) {
        self._onBootstrap = onBootstrap
    }

    public func setOnBootstrap(_ handler: ((VPNServer, Credentials) async -> ServerBootstrapAttempt)?) {
        self._onBootstrap = handler
    }

    public func bootstrap(
        server: VPNServer,
        credentials: Credentials,
        context: BootstrapContext,
        attempt: BootstrapAttemptContext,
        policy: BootstrapPolicy
    ) async -> ServerBootstrapAttempt {
        callCount += 1
        calledServers.append(server.id)
        if Task.isCancelled {
            return .failure(ServerProbeFailure(
                server: server, kind: .cancelled,
                metrics: ProbeMetrics(serverID: server.id, queuePosition: attempt.queuePosition,
                    queuedAtMs: 0, startedAtMs: 0, completedAtMs: 0,
                    dnsMs: nil, tcpConnectMs: nil, fakeHandshakeMs: nil,
                    tlsHandshakeMs: nil, loginHTTPMs: nil, bootstrapHTTPMs: nil,
                    totalMs: 0, cancellationRequestedAtMs: 0, cancellationCompletedAtMs: 0,
                    outcome: .cancelled),
                safeDiagnostic: "cancelled"
            ))
        }
        if let handler = _onBootstrap {
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
