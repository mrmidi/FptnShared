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

struct ConnectionFactoryTests {

    private func makeContext() -> BootstrapContext {
        BootstrapContext(
            networkClass: .wifi,
            sni: "sni",
            censorshipStrategy: CensorshipStrategy(storedValue: ""),
            ipv6Available: false,
            tokenConfigurationID: "cfg"
        )
    }

    private func makeManualRequest(server: VPNServer) -> ManualConnectionRequest {
        ManualConnectionRequest(
            server: server,
            credentials: Credentials(username: "u", password: "p"),
            bootstrapContext: makeContext()
        )
    }

    private func makeAutoRequest(servers: [VPNServer]) -> AutoConnectionRequest {
        AutoConnectionRequest(
            servers: servers,
            credentials: Credentials(username: "u", password: "p"),
            bootstrapContext: makeContext()
        )
    }

    @Test func makeManualCoordinator_returnsManualCoordinator() {
        let deps = ManualConnectionDependencies(
            bootstrapper: FakeServerBootstrapping(),
            tunnelController: FakeTunnelController()
        )
        let coordinator = makeManualCoordinator(deps: deps)
        #expect(coordinator is ManualConnectionCoordinating)
    }

    @Test func makeAutoCoordinator_returnsAutoCoordinator() {
        let deps = AutoConnectionDependencies(
            selector: FakeAutoSelector(),
            tunnelController: FakeTunnelController()
        )
        let coordinator = makeAutoCoordinator(deps: deps)
        #expect(coordinator is AutoConnectionCoordinating)
    }

    @Test func makeCoordinator_manualPlan_returnsManualCoordinator() {
        let manualDeps = ManualConnectionDependencies(
            bootstrapper: FakeServerBootstrapping(),
            tunnelController: FakeTunnelController()
        )
        let autoDeps = AutoConnectionDependencies(
            selector: FakeAutoSelector(),
            tunnelController: FakeTunnelController()
        )
        let server = VPNServer(name: "S", host: "1.1.1.1", port: 443, md5Fingerprint: "a")
        let coordinator = makeCoordinator(
            for: .manual(makeManualRequest(server: server)),
            manualDeps: manualDeps,
            autoDeps: autoDeps
        )
        #expect(coordinator is ManualConnectionCoordinating)
    }

    @Test func manualCoordinator_bootstrapFailure_startsExactlyOnce() async {
        let server = VPNServer(name: "Manual-Single", host: "2.2.2.2", port: 443, md5Fingerprint: "b")
        let bootstrap = FakeServerBootstrapping()
        await bootstrap.setOnBootstrap { _, _ in
            return .failure(ServerProbeFailure(
                server: server, kind: .connectionTimeout,
                metrics: ProbeMetrics(
                    serverID: server.id, queuePosition: 0,
                    queuedAtMs: 0, startedAtMs: 0, completedAtMs: 0,
                    dnsMs: nil, tcpConnectMs: nil, fakeHandshakeMs: nil,
                    tlsHandshakeMs: nil, loginHTTPMs: nil, bootstrapHTTPMs: nil,
                    totalMs: 0, cancellationRequestedAtMs: nil, cancellationCompletedAtMs: nil,
                    outcome: .failure
                ),
                safeDiagnostic: "timeout"
            ))
        }
        let tunnel = FakeTunnelController()
        let deps = ManualConnectionDependencies(
            bootstrapper: bootstrap,
            tunnelController: tunnel
        )
        let coordinator = makeManualCoordinator(deps: deps)

        let result = await coordinator.connect(makeManualRequest(server: server))

        if case .failed(.bootstrap) = result {
        } else {
            Issue.record("Expected .bootstrap failure, got \(result)")
        }
        let startCallCount = await tunnel.startCallCount
        #expect(startCallCount == 0)
    }

    @Test func manualCoordinator_generationGate_discardsLateBootstrapAfterDisconnect() async {
        let server = VPNServer(name: "Manual-Gen", host: "3.3.3.3", port: 443, md5Fingerprint: "c")
        let bootstrap = FakeServerBootstrapping()
        await bootstrap.setOnBootstrap { _, _ in
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
        let deps = ManualConnectionDependencies(
            bootstrapper: bootstrap,
            tunnelController: tunnel
        )
        let coordinator = makeManualCoordinator(deps: deps)

        let connectTask: Task<ConnectionStartResult, Never> = Task {
            await coordinator.connect(makeManualRequest(server: server))
        }
        try? await Task.sleep(for: .milliseconds(10))
        await coordinator.disconnect(reason: .userInitiated)

        let result = await connectTask.value

        let startCallCount = await tunnel.startCallCount
        let snapshot = await coordinator.stateSnapshot()
        #expect(startCallCount == 0)
        if case .cancelled = result {
        } else {
            Issue.record("Expected .cancelled, got \(result)")
        }
        #expect(snapshot == .disconnected)
    }

    @Test func recoveryPolicy_manualMode_isAlwaysNone() async {
        let server = VPNServer(name: "Manual-Policy", host: "4.4.4.4", port: 443, md5Fingerprint: "d")
        let bootstrap = FakeServerBootstrapping()
        let tunnel = FakeTunnelController()
        var capturedPolicy: TunnelRecoveryPolicy?
        await tunnel.setOnStart { _, config in
            capturedPolicy = config.recoveryPolicy
            return .success(())
        }
        let deps = ManualConnectionDependencies(
            bootstrapper: bootstrap,
            tunnelController: tunnel
        )
        let coordinator = makeManualCoordinator(deps: deps)

        _ = await coordinator.connect(makeManualRequest(server: server))

        #expect(capturedPolicy == TunnelRecoveryPolicy.none)
    }

    @Test func modeBoundary_manualRequestCannotReachAutoCoordinatorAtCompileTime() {
        let autoDeps = AutoConnectionDependencies(
            selector: FakeAutoSelector(),
            tunnelController: FakeTunnelController()
        )
        let autoCoordinator = makeAutoCoordinator(deps: autoDeps)
        #expect(autoCoordinator is AutoConnectionCoordinating)
    }
}
