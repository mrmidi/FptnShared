/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
import Testing
import FptnSharedCore
import FptnServerSelection
import FptnConnectionOrchestration

struct AutoConnectionCoordinatorTests {

    @Test func connect_successfulSelection_startsTunnelWithAutomaticRecovery() async {
        let server = VPNServer(name: "Auto-Success", host: "1.1.1.1", port: 443, md5Fingerprint: "a")
        let selector = FakeAutoSelector()
        selector.onSelect = { _ in
            SelectionOutcome(
                result: .success(ServerBootstrapResult(
                    server: server, accessToken: "auto-token",
                    dnsIPv4: "10.0.0.1", dnsIPv6: nil,
                    metrics: ProbeMetrics(
                        serverID: server.id, queuePosition: 0,
                        queuedAtMs: 0, startedAtMs: 0, completedAtMs: 0,
                        dnsMs: nil, tcpConnectMs: nil, fakeHandshakeMs: nil,
                        tlsHandshakeMs: nil, loginHTTPMs: nil, bootstrapHTTPMs: nil,
                        totalMs: 100, cancellationRequestedAtMs: nil, cancellationCompletedAtMs: nil,
                        outcome: .success
                    )
                )),
                attempts: []
            )
        }
        let tunnel = FakeTunnelController()
        var capturedPolicy: TunnelRecoveryPolicy?
        tunnel.onStart = { _, config in
            capturedPolicy = config.recoveryPolicy
            return .success(())
        }
        let coordinator = AutoConnectionCoordinator(
            selector: selector,
            tunnelController: tunnel
        )

        let result = await coordinator.connect()

        if case .started = result {
        } else {
            Issue.record("Expected .started, got \(result)")
        }
        #expect(tunnel.startCallCount == 1)
        #expect(capturedPolicy == .automatic(AutoTunnelRecoveryPolicy(sameServerAttempts: 2, reconnectDelaySeconds: 2)))
    }

    @Test func connect_allCandidatesFailed_returnsNoServersFailure() async {
        let selector = FakeAutoSelector()
        selector.onSelect = { _ in
            SelectionOutcome(result: .allCandidatesFailed(SelectionFailureSummary(
                attemptedCount: 0, failuresByKind: [:], representativeFailure: nil
            )), attempts: [])
        }
        let tunnel = FakeTunnelController()
        let coordinator = AutoConnectionCoordinator(
            selector: selector,
            tunnelController: tunnel
        )

        let result = await coordinator.connect()

        if case .failed(.noServers) = result {
        } else {
            Issue.record("Expected .noServers, got \(result)")
        }
        #expect(tunnel.startCallCount == 0)
    }

    @Test func networkLoss_entersWaitingForNetwork() async {
        let server = VPNServer(name: "Auto-Net", host: "2.2.2.2", port: 443, md5Fingerprint: "b")
        let selector = FakeAutoSelector()
        selector.onSelect = { _ in
            SelectionOutcome(
                result: .success(ServerBootstrapResult(
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
                )),
                attempts: []
            )
        }
        let tunnel = FakeTunnelController()
        let coordinator = AutoConnectionCoordinator(
            selector: selector,
            tunnelController: tunnel
        )

        guard case .started(let episodeID) = await coordinator.connect() else {
            Issue.record("connect failed")
            return
        }

        await coordinator.handle(.tunnelDisconnected(episodeID, .networkLost))

        let snapshot = await coordinator.stateSnapshot()
        #expect(snapshot == .failed(reason: "waiting for network"))
        #expect(tunnel.startCallCount == 1)
    }

    @Test func userDisconnect_furtherEventsIgnored() async {
        let server = VPNServer(name: "Auto-UserDisc", host: "3.3.3.3", port: 443, md5Fingerprint: "c")
        let selector = FakeAutoSelector()
        selector.onSelect = { _ in
            SelectionOutcome(
                result: .success(ServerBootstrapResult(
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
                )),
                attempts: []
            )
        }
        let tunnel = FakeTunnelController()
        let coordinator = AutoConnectionCoordinator(
            selector: selector,
            tunnelController: tunnel
        )

        guard case .started(let episodeID) = await coordinator.connect() else {
            Issue.record("connect failed")
            return
        }

        await coordinator.disconnect(reason: .userInitiated)
        await coordinator.handle(.tunnelDisconnected(episodeID, .remoteClosed))

        let snapshot = await coordinator.stateSnapshot()
        #expect(snapshot == .idle)
    }
}
