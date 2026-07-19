/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
import Testing
import FptnSharedCore
import FptnServerSelection
import FptnConnectionOrchestration
import FptnSharedTestSupport

struct ManualConnectionCoordinatorTests {

    private func makeContext() -> BootstrapContext {
        BootstrapContext(
            networkClass: .wifi,
            sni: "test.example.com",
            censorshipStrategy: CensorshipStrategy(storedValue: ""),
            ipv6Available: false,
            tokenConfigurationID: "test_cfg"
        )
    }

    private func makeServer(_ name: String, host: String) -> VPNServer {
        VPNServer(name: name, host: host, port: 443, md5Fingerprint: "fp_\(name)")
    }

    private func makeRequest(server: VPNServer) -> ManualConnectionRequest {
        ManualConnectionRequest(
            server: server,
            credentials: Credentials(username: "user", password: "pass"),
            bootstrapContext: makeContext()
        )
    }

    @Test func connect_performsExactlyOneBootstrapAttempt() async {
        let server = makeServer("Manual-1", host: "1.1.1.1")
        let bootstrap = FakeServerBootstrapping()
        let tunnel = FakeTunnelController()
        let coordinator = ManualConnectionCoordinator(
            bootstrapper: bootstrap,
            tunnelController: tunnel
        )

        let result = await coordinator.connect(makeRequest(server: server))

        let callCount = await bootstrap.callCount
        let startCallCount = await tunnel.startCallCount
        #expect(callCount == 1)
        #expect(startCallCount == 1)
        if case .started = result {
        } else {
            Issue.record("Expected .started, got \(result)")
        }
    }

    @Test func connect_usesSuppliedCredentialsAndContext() async {
        let server = makeServer("Manual-Creds", host: "2.2.2.2")
        let bootstrap = FakeServerBootstrapping()
        let tunnel = FakeTunnelController()
        var capturedServer: String?
        await bootstrap.setOnBootstrap { s, _ in
            capturedServer = s.host
            return .success(ServerBootstrapResult(
                server: s, accessToken: "tok", dnsIPv4: "10.0.0.1", dnsIPv6: nil,
                metrics: ProbeMetrics(
                    serverID: s.id, queuePosition: 0,
                    queuedAtMs: 0, startedAtMs: 0, completedAtMs: 0,
                    dnsMs: nil, tcpConnectMs: nil, fakeHandshakeMs: nil,
                    tlsHandshakeMs: nil, loginHTTPMs: nil, bootstrapHTTPMs: nil,
                    totalMs: 50, cancellationRequestedAtMs: nil, cancellationCompletedAtMs: nil,
                    outcome: .success
                )
            ))
        }
        let coordinator = ManualConnectionCoordinator(
            bootstrapper: bootstrap,
            tunnelController: tunnel
        )

        _ = await coordinator.connect(makeRequest(server: server))

        #expect(capturedServer == "2.2.2.2")
    }

    @Test func bootstrapFailure_doesNotRetryOrStartTunnel() async {
        let server = makeServer("Manual-Fail", host: "3.3.3.3")
        let bootstrap = FakeServerBootstrapping()
        await bootstrap.setOnBootstrap { _, _ in
            return .failure(ServerProbeFailure(
                server: server, kind: .connectionRefused,
                metrics: ProbeMetrics(
                    serverID: server.id, queuePosition: 0,
                    queuedAtMs: 0, startedAtMs: 0, completedAtMs: 0,
                    dnsMs: nil, tcpConnectMs: nil, fakeHandshakeMs: nil,
                    tlsHandshakeMs: nil, loginHTTPMs: nil, bootstrapHTTPMs: nil,
                    totalMs: 0, cancellationRequestedAtMs: nil, cancellationCompletedAtMs: nil,
                    outcome: .failure
                ),
                safeDiagnostic: "refused"
            ))
        }
        let tunnel = FakeTunnelController()
        let coordinator = ManualConnectionCoordinator(
            bootstrapper: bootstrap,
            tunnelController: tunnel
        )

        let result = await coordinator.connect(makeRequest(server: server))

        if case .failed(let failure) = result {
            #expect(failure == .bootstrap("refused"))
        } else {
            Issue.record("Expected .failed, got \(result)")
        }
        let callCount = await bootstrap.callCount
        let startCallCount = await tunnel.startCallCount
        #expect(callCount == 1)
        #expect(startCallCount == 0)
    }

    @Test func disconnect_stopsActiveEpisode() async {
        let server = makeServer("Manual-Disc", host: "4.4.4.4")
        let bootstrap = FakeServerBootstrapping()
        let tunnel = FakeTunnelController()
        let coordinator = ManualConnectionCoordinator(
            bootstrapper: bootstrap,
            tunnelController: tunnel
        )

        guard case .started(let episodeID) = await coordinator.connect(makeRequest(server: server)) else {
            Issue.record("connect failed")
            return
        }

        await coordinator.disconnect(reason: .userInitiated)

        let stopCallCount = await tunnel.stopCallCount
        let stoppedEpisodes = await tunnel.stoppedEpisodes
        #expect(stopCallCount == 1)
        #expect(stoppedEpisodes == [episodeID])
        let snapshot = await coordinator.stateSnapshot()
        #expect(snapshot == .disconnected)
    }

    @Test func disconnectDuringSelection_stopsNothing() async {
        let server = makeServer("Manual-SelDisc", host: "5.5.5.5")
        let bootstrap = FakeServerBootstrapping()
        await bootstrap.setOnBootstrap { _, _ in
            try? await Task.sleep(for: .milliseconds(50))
            return .success(ServerBootstrapResult(
                server: server, accessToken: "tok",
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
            bootstrapper: bootstrap,
            tunnelController: tunnel
        )

        let connectTask = Task { await coordinator.connect(makeRequest(server: server)) }
        try? await Task.sleep(for: .milliseconds(10))
        await coordinator.disconnect(reason: .userInitiated)

        _ = await connectTask.value

        let stopCallCount = await tunnel.stopCallCount
        let stoppedEpisodes = await tunnel.stoppedEpisodes
        #expect(stopCallCount == 0)
        #expect(stoppedEpisodes.isEmpty)
    }

    @Test func tunnelFailure_doesNotRetry() async {
        let server = makeServer("Manual-TunnelFail", host: "6.6.6.6")
        let bootstrap = FakeServerBootstrapping()
        let tunnel = FakeTunnelController()
        await tunnel.setShouldSucceed(false)
        let coordinator = ManualConnectionCoordinator(
            bootstrapper: bootstrap,
            tunnelController: tunnel
        )

        let result = await coordinator.connect(makeRequest(server: server))

        if case .failed(.tunnelRefused) = result {
        } else {
            Issue.record("Expected .tunnelRefused, got \(result)")
        }
        let startCallCount = await tunnel.startCallCount
        #expect(startCallCount == 1)
    }

    @Test func disconnectDuringBootstrap_discardsLateCompletion_withoutOverwritingNewerState() async {
        let server = makeServer("Manual-Cancel", host: "7.7.7.7")
        let bootstrap = FakeServerBootstrapping()
        await bootstrap.setOnBootstrap { _, _ in
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
            bootstrapper: bootstrap,
            tunnelController: tunnel
        )

        let connectTask = Task { await coordinator.connect(makeRequest(server: server)) }
        try? await Task.sleep(for: .milliseconds(10))
        await coordinator.disconnect(reason: .userInitiated)

        let result = await connectTask.value

        let startCallCount = await tunnel.startCallCount
        let snapshot = await coordinator.stateSnapshot()
        let stoppedEpisodes = await tunnel.stoppedEpisodes
        #expect(startCallCount == 0)
        #expect(stoppedEpisodes.isEmpty)
        if case .cancelled = result {
        } else {
            Issue.record("Expected .cancelled, got \(result)")
        }
        #expect(snapshot == .disconnected)
    }

    @Test func unexpectedTunnelDisconnect_doesNotRecover() async {
        let server = makeServer("Manual-Drop", host: "8.8.8.8")
        let bootstrap = FakeServerBootstrapping()
        let tunnel = FakeTunnelController()
        let coordinator = ManualConnectionCoordinator(
            bootstrapper: bootstrap,
            tunnelController: tunnel
        )

        guard case .started(let episodeID) = await coordinator.connect(makeRequest(server: server)) else {
            Issue.record("connect failed")
            return
        }

        await coordinator.handle(.tunnelDisconnected(episodeID, .remoteClosed))

        let snapshot = await coordinator.stateSnapshot()
        #expect(snapshot == .disconnected)
        let startCallCount = await tunnel.startCallCount
        #expect(startCallCount == 1)
    }

    @Test func networkRestoration_doesNotReconnect() async {
        let server = makeServer("Manual-Net", host: "9.9.9.9")
        let bootstrap = FakeServerBootstrapping()
        let tunnel = FakeTunnelController()
        let coordinator = ManualConnectionCoordinator(
            bootstrapper: bootstrap,
            tunnelController: tunnel
        )

        guard case .started(let episodeID) = await coordinator.connect(makeRequest(server: server)) else {
            Issue.record("connect failed")
            return
        }

        await coordinator.handle(.tunnelDisconnected(episodeID, .networkLost))
        await coordinator.handle(.networkBecameSatisfied)

        let snapshot = await coordinator.stateSnapshot()
        #expect(snapshot == .disconnected)
        let startCallCount = await tunnel.startCallCount
        #expect(startCallCount == 1)
    }

    @Test func staleTunnelStart_cannotStopNewerEpisode() async {
        let serverA = makeServer("Manual-Stale", host: "10.10.10.10")
        let serverB = makeServer("Manual-New", host: "11.11.11.11")
        let bootstrap = FakeServerBootstrapping()
        let tunnel = FakeTunnelController()

        var firstEpisode: ConnectionEpisodeID?
        var releaseFirst = false

        await tunnel.setOnStart { episodeID, _ in
            if firstEpisode == nil {
                firstEpisode = episodeID
                while !releaseFirst {
                    try? await Task.sleep(for: .milliseconds(5))
                }
            }
            return .success(())
        }

        let coordinator = ManualConnectionCoordinator(
            bootstrapper: bootstrap,
            tunnelController: tunnel
        )

        let firstTask = Task { await coordinator.connect(makeRequest(server: serverA)) }

        while await tunnel.startCallCount < 1 {
            try? await Task.sleep(for: .milliseconds(5))
        }

        await coordinator.disconnect(reason: .userInitiated)
        let secondTask = Task { await coordinator.connect(makeRequest(server: serverB)) }
        try? await Task.sleep(for: .milliseconds(20))
        releaseFirst = true

        _ = await firstTask.value
        _ = await secondTask.value

        let stoppedEpisodes = await tunnel.stoppedEpisodes
        let startCallCount = await tunnel.startCallCount
        let startedEpisodes = await tunnel.startedEpisodes

        #expect(startCallCount == 2)
        #expect(startedEpisodes.count == 2)

        guard let episodeB = startedEpisodes.last else {
            Issue.record("No second episode started")
            return
        }
        #expect(!stoppedEpisodes.contains(episodeB))

        let snapshot = await coordinator.stateSnapshot()
        #expect(snapshot == .connected(episodeID: episodeB))
    }
}
