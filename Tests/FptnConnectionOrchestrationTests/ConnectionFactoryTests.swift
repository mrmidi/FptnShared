/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
import Testing
import FptnSharedCore
import FptnServerSelection
import FptnConnectionOrchestration

struct ConnectionFactoryTests {

    @Test func makeCoordinator_manual_intent_returnsManualCoordinator() {
        let deps = ConnectionDependencies(
            nativeBootstrap: FakeBootstrap(),
            autoSelector: FakeAutoSelector(),
            tunnelController: FakeTunnelController()
        )
        let server = VPNServer(name: "S", host: "1.1.1.1", port: 443, md5Fingerprint: "a")
        let coordinator = makeCoordinator(for: .manual(server), deps: deps)

        #expect(coordinator is ManualConnectionCoordinator)
    }

    @Test func makeCoordinator_auto_intent_returnsAutoCoordinator() {
        let deps = ConnectionDependencies(
            nativeBootstrap: FakeBootstrap(),
            autoSelector: FakeAutoSelector(),
            tunnelController: FakeTunnelController()
        )
        let coordinator = makeCoordinator(for: .auto, deps: deps)

        #expect(coordinator is AutoConnectionCoordinator)
    }

    @Test func manualCoordinator_bootstrapFailure_startsExactlyOnce() async {
        let server = VPNServer(name: "Manual-Single", host: "2.2.2.2", port: 443, md5Fingerprint: "b")
        let bootstrap = FakeBootstrap()
        bootstrap.onBootstrap = { _, _ in
            return .failure(ServerBootstrapFailure(kind: "timeout", message: "timeout"))
        }
        let tunnel = FakeTunnelController()
        let deps = ConnectionDependencies(
            nativeBootstrap: bootstrap,
            autoSelector: FakeAutoSelector(),
            tunnelController: tunnel
        )
        let coordinator = makeCoordinator(for: .manual(server), deps: deps)

        let result = await coordinator.connect()

        if case .failed(.bootstrap) = result {
        } else {
            Issue.record("Expected .bootstrap failure, got \(result)")
        }
        #expect(tunnel.startCallCount == 0)
    }

    @Test func manualCoordinator_generationGate_discardsLateBootstrapAfterDisconnect() async {
        let server = VPNServer(name: "Manual-Gen", host: "3.3.3.3", port: 443, md5Fingerprint: "c")
        let bootstrap = FakeBootstrap()
        bootstrap.onBootstrap = { _, _ in
            try? await Task.sleep(for: .milliseconds(50))
            return .success(ServerBootstrapResult(
                server: server, accessToken: "token",
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
        let deps = ConnectionDependencies(
            nativeBootstrap: bootstrap,
            autoSelector: FakeAutoSelector(),
            tunnelController: tunnel
        )
        let coordinator = makeCoordinator(for: .manual(server), deps: deps)

        let connectTask: Task<ConnectionStartResult, Never> = Task {
            await coordinator.connect()
        }
        try? await Task.sleep(for: .milliseconds(10))
        await coordinator.disconnect(reason: .userInitiated)

        let result = await connectTask.value

        #expect(tunnel.startCallCount == 0)
        if case .cancelled = result {
        } else {
            Issue.record("Expected .cancelled, got \(result)")
        }
    }

    @Test func recoveryPolicy_manualMode_isAlwaysNone() async {
        let server = VPNServer(name: "Manual-Policy", host: "4.4.4.4", port: 443, md5Fingerprint: "d")
        let bootstrap = FakeBootstrap()
        let tunnel = FakeTunnelController()
        var capturedPolicy: TunnelRecoveryPolicy?
        tunnel.onStart = { _, config in
            capturedPolicy = config.recoveryPolicy
            return .success(())
        }
        let deps = ConnectionDependencies(
            nativeBootstrap: bootstrap,
            autoSelector: FakeAutoSelector(),
            tunnelController: tunnel
        )
        let coordinator = makeCoordinator(for: .manual(server), deps: deps)

        _ = await coordinator.connect()

        #expect(capturedPolicy == TunnelRecoveryPolicy.none)
    }
}
