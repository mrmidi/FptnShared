/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
import Testing
import FptnSharedCore
import FptnSharedTunnel
import FptnServerSelection
import FptnConnectionOrchestration
import FptnSharedTestSupport

struct AutoConnectionCoordinatorTests {

    private func makeServer(_ name: String, host: String) -> VPNServer {
        VPNServer(name: name, host: host, port: 443, md5Fingerprint: "fp_\(name)")
    }

    private func makeContext() -> BootstrapContext {
        BootstrapContext(
            networkClass: .wifi,
            sni: "test.example.com",
            censorshipStrategy: CensorshipStrategy(storedValue: ""),
            ipv6Available: false,
            tokenConfigurationID: "test_cfg"
        )
    }

    private func makeRequest(servers: [VPNServer]) -> AutoConnectionRequest {
        AutoConnectionRequest(
            servers: servers,
            credentials: Credentials(username: "user", password: "pass"),
            bootstrapContext: makeContext()
        )
    }

    private func successRun(server: VPNServer) -> SelectionRun {
        SelectionRun(
            result: .success(ServerBootstrapResult(
                server: server, accessToken: "tok",
                dnsIPv4: "10.0.0.1", dnsIPv6: nil,
                metrics: ProbeMetrics(
                    serverID: server.id, queuePosition: 0, queuedAtMs: 0, startedAtMs: 0, completedAtMs: 0,
                    dnsMs: nil, tcpConnectMs: nil, fakeHandshakeMs: nil,
                    tlsHandshakeMs: nil, loginHTTPMs: nil, bootstrapHTTPMs: nil,
                    totalMs: 100, cancellationRequestedAtMs: nil, cancellationCompletedAtMs: nil,
                    outcome: .success
                )
            )),
            observations: [],
            statistics: SelectionRunStatistics(
                candidateCount: 1, startedCount: 1, completedCount: 1,
                neverStartedCount: 0, peakActiveProbes: 1, timeToWinnerMs: 100, deadlineTriggered: false
            )
        )
    }

    @Test func connect_successfulSelection_startsTunnelWithAutomaticRecovery() async {
        let server = makeServer("Auto-Success", host: "1.1.1.1")
        let selector = FakeAutoSelector()
        await selector.setOnSelect { _ in self.successRun(server: server) }
        let tunnel = FakeTunnelController()
        var capturedPolicy: TunnelRecoveryPolicy?
        await tunnel.setOnStart { _, config in
            capturedPolicy = config.recoveryPolicy
            return .success(())
        }
        let coordinator = AutoConnectionCoordinator(selector: selector, tunnelController: tunnel)

        let result = await coordinator.connect(makeRequest(servers: [server]))

        if case .started = result {
        } else {
            Issue.record("Expected .started, got \(result)")
        }
        let startCallCount = await tunnel.startCallCount
        #expect(startCallCount == 1)
        #expect(capturedPolicy == .automatic(AutoTunnelRecoveryPolicy(sameServerAttempts: 2, reconnectDelaySeconds: 2)))
    }

    @Test func connect_allCandidatesFailed_returnsNoServersFailure() async {
        let selector = FakeAutoSelector()
        await selector.setOnSelect { _ in
            SelectionRun(
                result: .allCandidatesFailed(SelectionFailureSummary(attemptedCount: 0, failuresByKind: [:], representativeFailure: nil)),
                observations: [],
                statistics: SelectionRunStatistics(candidateCount: 0, startedCount: 0, completedCount: 0, neverStartedCount: 0, peakActiveProbes: 0, timeToWinnerMs: nil, deadlineTriggered: false)
            )
        }
        let tunnel = FakeTunnelController()
        let coordinator = AutoConnectionCoordinator(selector: selector, tunnelController: tunnel)

        let result = await coordinator.connect(makeRequest(servers: []))

        if case .failed(.noServers) = result {
        } else {
            Issue.record("Expected .noServers, got \(result)")
        }
        let startCallCount = await tunnel.startCallCount
        #expect(startCallCount == 0)
    }

    @Test func disconnectDuringSelection_doesNotStartTunnel() async {
        let server = makeServer("Auto-Cancel", host: "2.2.2.2")
        let selector = FakeAutoSelector()
        await selector.setOnSelect { _ in
            try? await Task.sleep(for: .milliseconds(50))
            return self.successRun(server: server)
        }
        let tunnel = FakeTunnelController()
        let coordinator = AutoConnectionCoordinator(selector: selector, tunnelController: tunnel)

        let connectTask: Task<ConnectionStartResult, Never> = Task {
            await coordinator.connect(makeRequest(servers: [server]))
        }
        try? await Task.sleep(for: .milliseconds(10))
        await coordinator.disconnect(reason: .userInitiated)

        let result = await connectTask.value

        let startCallCount = await tunnel.startCallCount
        #expect(startCallCount == 0)
        if case .cancelled = result {
        } else {
            Issue.record("Expected .cancelled, got \(result)")
        }
    }

    @Test func userInitiatedStop_isTerminal_entersIdle() async {
        let server = makeServer("Auto-User", host: "3.3.3.3")
        let selector = FakeAutoSelector()
        await selector.setOnSelect { _ in self.successRun(server: server) }
        let tunnel = FakeTunnelController()
        let coordinator = AutoConnectionCoordinator(selector: selector, tunnelController: tunnel)

        guard case .started(let episodeID) = await coordinator.connect(makeRequest(servers: [server])) else {
            Issue.record("connect failed")
            return
        }

        await coordinator.handle(.tunnelDisconnected(episodeID, .userInitiated))

        let snapshot = await coordinator.stateSnapshot()
        #expect(snapshot == .idle)
    }

    @Test func authenticationFailedStop_isTerminal() async {
        let server = makeServer("Auto-Auth", host: "4.4.4.4")
        let selector = FakeAutoSelector()
        await selector.setOnSelect { _ in self.successRun(server: server) }
        let tunnel = FakeTunnelController()
        let coordinator = AutoConnectionCoordinator(selector: selector, tunnelController: tunnel)

        guard case .started(let episodeID) = await coordinator.connect(makeRequest(servers: [server])) else {
            Issue.record("connect failed")
            return
        }

        await coordinator.handle(.tunnelDisconnected(episodeID, .authenticationFailed))

        let snapshot = await coordinator.stateSnapshot()
        #expect(snapshot == .failed(reason: "authenticationRejected"))
    }

    @Test func networkLoss_entersWaitingForNetwork_notFailure() async {
        let server = makeServer("Auto-Net", host: "5.5.5.5")
        let selector = FakeAutoSelector()
        await selector.setOnSelect { _ in self.successRun(server: server) }
        let tunnel = FakeTunnelController()
        let coordinator = AutoConnectionCoordinator(selector: selector, tunnelController: tunnel)

        guard case .started(let episodeID) = await coordinator.connect(makeRequest(servers: [server])) else {
            Issue.record("connect failed")
            return
        }

        await coordinator.handle(.tunnelDisconnected(episodeID, .networkLost))

        let snapshot = await coordinator.stateSnapshot()
        #expect(snapshot == .waitingForNetwork)
    }

    @Test func remoteClosed_entersSelectingReplacement() async {
        let server = makeServer("Auto-Remote", host: "6.6.6.6")
        let selector = FakeAutoSelector()
        await selector.setOnSelect { _ in self.successRun(server: server) }
        let tunnel = FakeTunnelController()
        let coordinator = AutoConnectionCoordinator(selector: selector, tunnelController: tunnel)

        guard case .started(let episodeID) = await coordinator.connect(makeRequest(servers: [server])) else {
            Issue.record("connect failed")
            return
        }

        await coordinator.handle(.tunnelDisconnected(episodeID, .remoteClosed))

        let snapshot = await coordinator.stateSnapshot()
        #expect(snapshot == .selectingReplacement)
    }

    @Test func userDisconnect_furtherEventsIgnored() async {
        let server = makeServer("Auto-UserDisc", host: "7.7.7.7")
        let selector = FakeAutoSelector()
        await selector.setOnSelect { _ in self.successRun(server: server) }
        let tunnel = FakeTunnelController()
        let coordinator = AutoConnectionCoordinator(selector: selector, tunnelController: tunnel)

        guard case .started(let episodeID) = await coordinator.connect(makeRequest(servers: [server])) else {
            Issue.record("connect failed")
            return
        }

        await coordinator.disconnect(reason: .userInitiated)
        await coordinator.handle(.tunnelDisconnected(episodeID, .remoteClosed))

        let snapshot = await coordinator.stateSnapshot()
        #expect(snapshot == .idle)
    }

    @Test func disconnect_stopsActiveEpisode() async {
        let server = makeServer("Auto-Disc", host: "8.8.8.8")
        let selector = FakeAutoSelector()
        await selector.setOnSelect { _ in self.successRun(server: server) }
        let tunnel = FakeTunnelController()
        let coordinator = AutoConnectionCoordinator(selector: selector, tunnelController: tunnel)

        guard case .started(let episodeID) = await coordinator.connect(makeRequest(servers: [server])) else {
            Issue.record("connect failed")
            return
        }

        await coordinator.disconnect(reason: .userInitiated)

        let stopCallCount = await tunnel.stopCallCount
        let stoppedEpisodes = await tunnel.stoppedEpisodes
        #expect(stopCallCount == 1)
        #expect(stoppedEpisodes == [episodeID])
        let snapshot = await coordinator.stateSnapshot()
        #expect(snapshot == .idle)
    }

    @Test func disconnectDuringSelection_stopsNothing() async {
        let server = makeServer("Auto-SelDisc", host: "9.9.9.9")
        let selector = FakeAutoSelector()
        await selector.setOnSelect { _ in
            try? await Task.sleep(for: .milliseconds(50))
            return self.successRun(server: server)
        }
        let tunnel = FakeTunnelController()
        let coordinator = AutoConnectionCoordinator(selector: selector, tunnelController: tunnel)

        let connectTask: Task<ConnectionStartResult, Never> = Task {
            await coordinator.connect(makeRequest(servers: [server]))
        }
        try? await Task.sleep(for: .milliseconds(10))
        await coordinator.disconnect(reason: .userInitiated)

        _ = await connectTask.value

        let stopCallCount = await tunnel.stopCallCount
        let stoppedEpisodes = await tunnel.stoppedEpisodes
        #expect(stopCallCount == 0)
        #expect(stoppedEpisodes.isEmpty)
    }
}
