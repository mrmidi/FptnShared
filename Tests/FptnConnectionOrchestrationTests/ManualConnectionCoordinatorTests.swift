/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
import Testing
import FptnSharedCore
import FptnConnectionOrchestration

struct ManualConnectionCoordinatorTests {

    @Test func connect_performsExactlyOneBootstrapAttempt() async {
        let server = VPNServer(name: "Manual-1", host: "1.1.1.1", port: 443, md5Fingerprint: "a")
        let bootstrap = FakeBootstrap()
        let tunnel = FakeTunnelController()
        let coordinator = ManualConnectionCoordinator(
            server: server,
            bootstrapper: bootstrap,
            tunnelController: tunnel
        )

        let result = await coordinator.connect()

        #expect(bootstrap.callCount == 1)
        #expect(tunnel.startCallCount == 1)
        if case .started = result {
        } else {
            Issue.record("Expected .started, got \(result)")
        }
    }

    @Test func bootstrapFailure_doesNotRetryOrStartTunnel() async {
        let server = VPNServer(name: "Manual-Fail", host: "2.2.2.2", port: 443, md5Fingerprint: "b")
        let bootstrap = FakeBootstrap()
        bootstrap.onBootstrap = { _, _ in
            return .failure(ServerBootstrapFailure(kind: "connection_refused", message: "refused"))
        }
        let tunnel = FakeTunnelController()
        let coordinator = ManualConnectionCoordinator(
            server: server,
            bootstrapper: bootstrap,
            tunnelController: tunnel
        )

        let result = await coordinator.connect()

        if case .failed(let failure) = result {
            #expect(failure == .bootstrap("refused"))
        } else {
            Issue.record("Expected .failed, got \(result)")
        }
        #expect(bootstrap.callCount == 1)
        #expect(tunnel.startCallCount == 0)
    }

    @Test func disconnect_stopsTunnelAndEntersDisconnectedState() async {
        let server = VPNServer(name: "Manual-Disc", host: "3.3.3.3", port: 443, md5Fingerprint: "c")
        let bootstrap = FakeBootstrap()
        let tunnel = FakeTunnelController()
        let coordinator = ManualConnectionCoordinator(
            server: server,
            bootstrapper: bootstrap,
            tunnelController: tunnel
        )

        _ = await coordinator.connect()
        await coordinator.disconnect(reason: .userInitiated)

        #expect(tunnel.stopCallCount == 1)
        let snapshot = await coordinator.stateSnapshot()
        #expect(snapshot == .disconnected)
    }

    @Test func tunnelFailure_doesNotRetry() async {
        let server = VPNServer(name: "Manual-TunnelFail", host: "4.4.4.4", port: 443, md5Fingerprint: "d")
        let bootstrap = FakeBootstrap()
        let tunnel = FakeTunnelController()
        tunnel.shouldSucceed = false
        let coordinator = ManualConnectionCoordinator(
            server: server,
            bootstrapper: bootstrap,
            tunnelController: tunnel
        )

        let result = await coordinator.connect()

        if case .failed(.tunnelRefused) = result {
        } else {
            Issue.record("Expected .tunnelRefused, got \(result)")
        }
        #expect(tunnel.startCallCount == 1)
    }

    @Test func disconnectDuringBootstrap_discardsLateCompletion() async {
        let server = VPNServer(name: "Manual-Cancel", host: "5.5.5.5", port: 443, md5Fingerprint: "e")
        let bootstrap = FakeBootstrap()
        bootstrap.onBootstrap = { _, _ in
            try? await Task.sleep(for: .milliseconds(50))
            return .success(ServerBootstrapResult(
                server: server, accessToken: "late-token",
                dnsIPv4: "10.0.0.1", dnsIPv6: nil,
                metrics: ProbeMetrics(
                    serverID: server.id, queuePosition: 0,
                    queuedAtMs: 0, startedAtMs: 0, completedAtMs: 0,
                    dnsMs: nil, tcpConnectMs: nil, fakeHandshakeMs: nil,
                    tlsHandshakeMs: nil, loginHTTPMs: nil, bootstrapHTTPMs: nil,
                    totalMs: 50, cancellationRequestedAtMs: nil, cancellationCompletedAtMs: nil,
                    outcome: .success
                )
            ))
        }
        let tunnel = FakeTunnelController()
        let coordinator = ManualConnectionCoordinator(
            server: server,
            bootstrapper: bootstrap,
            tunnelController: tunnel
        )

        let connectTask = Task { await coordinator.connect() }
        try? await Task.sleep(for: .milliseconds(10))
        await coordinator.disconnect(reason: .userInitiated)

        let result = await connectTask.value

        #expect(tunnel.startCallCount == 0)
        if case .cancelled = result {
        } else {
            Issue.record("Expected .cancelled, got \(result)")
        }
    }

    @Test func unexpectedTunnelDisconnect_doesNotRecover() async {
        let server = VPNServer(name: "Manual-Drop", host: "6.6.6.6", port: 443, md5Fingerprint: "f")
        let bootstrap = FakeBootstrap()
        let tunnel = FakeTunnelController()
        let coordinator = ManualConnectionCoordinator(
            server: server,
            bootstrapper: bootstrap,
            tunnelController: tunnel
        )

        guard case .started(let episodeID) = await coordinator.connect() else {
            Issue.record("connect failed")
            return
        }

        await coordinator.handle(.tunnelDisconnected(episodeID, .remoteClosed))

        let snapshot = await coordinator.stateSnapshot()
        #expect(snapshot == .disconnected)
        #expect(tunnel.startCallCount == 1)
    }

    @Test func networkRestoration_doesNotReconnect() async {
        let server = VPNServer(name: "Manual-Net", host: "7.7.7.7", port: 443, md5Fingerprint: "g")
        let bootstrap = FakeBootstrap()
        let tunnel = FakeTunnelController()
        let coordinator = ManualConnectionCoordinator(
            server: server,
            bootstrapper: bootstrap,
            tunnelController: tunnel
        )

        guard case .started(let episodeID) = await coordinator.connect() else {
            Issue.record("connect failed")
            return
        }

        await coordinator.handle(.tunnelDisconnected(episodeID, .networkLost))
        await coordinator.handle(.networkBecameSatisfied)

        let snapshot = await coordinator.stateSnapshot()
        #expect(snapshot == .disconnected)
        #expect(tunnel.startCallCount == 1)
    }

    @Test func manualCoordinator_hasNoHealthStoreDependency() async {
        let server = VPNServer(name: "Manual-Health", host: "8.8.8.8", port: 443, md5Fingerprint: "h")
        let bootstrap = FakeBootstrap()
        let tunnel = FakeTunnelController()
        let coordinator = ManualConnectionCoordinator(
            server: server,
            bootstrapper: bootstrap,
            tunnelController: tunnel
        )
        let result = await coordinator.connect()
        if case .started = result {
            #expect(true)
        } else {
            Issue.record("Expected success, got \(result)")
        }
    }
}
