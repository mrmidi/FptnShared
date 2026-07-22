/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
import Testing
import FptnSharedCore
import FptnSharedTunnel
import FptnServerSelection
import FptnSharedTestSupport

struct FptnServerSelectionTests {

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

    private func makeRequest(servers: [VPNServer], bootstrap: any ServerBootstrapping) -> (SelectionRequest, InMemoryHealthStore) {
        let store = InMemoryHealthStore()
        let request = SelectionRequest(
            servers: servers,
            credentials: Credentials(username: "user", password: "pass"),
            context: makeContext(),
            bootstrapPolicy: .production,
            selectionPolicy: .production
        )
        return (request, store)
    }

    @Test func select_retainsAllCandidatesInQueue() async {
        let servers = [
            makeServer("A", host: "1.1.1.1"),
            makeServer("B", host: "2.2.2.2"),
            makeServer("C", host: "3.3.3.3"),
            makeServer("D", host: "4.4.4.4"),
        ]
        let bootstrap = FakeServerBootstrapping()
        await bootstrap.setOnBootstrap { server, _ in
            if server.host == "1.1.1.1" {
                return .failure(ServerProbeFailure(
                    server: server, kind: .connectionTimeout,
                    metrics: ProbeMetrics(serverID: server.id, queuePosition: 0, queuedAtMs: 0, startedAtMs: 0, completedAtMs: 0,
                        dnsMs: nil, tcpConnectMs: nil, fakeHandshakeMs: nil, tlsHandshakeMs: nil, loginHTTPMs: nil, bootstrapHTTPMs: nil,
                        totalMs: 100, cancellationRequestedAtMs: nil, cancellationCompletedAtMs: nil, outcome: .failure),
                    safeDiagnostic: "timeout"
                ))
            }
            return .success(ServerBootstrapResult(
                server: server, accessToken: "tok", dnsIPv4: "10.0.0.1", dnsIPv6: nil,
                metrics: ProbeMetrics(serverID: server.id, queuePosition: 0, queuedAtMs: 0, startedAtMs: 0, completedAtMs: 0,
                    dnsMs: nil, tcpConnectMs: nil, fakeHandshakeMs: nil, tlsHandshakeMs: nil, loginHTTPMs: nil, bootstrapHTTPMs: nil,
                    totalMs: 50, cancellationRequestedAtMs: nil, cancellationCompletedAtMs: nil, outcome: .success)
            ))
        }
        let (request, store) = makeRequest(servers: servers, bootstrap: bootstrap)
        let selector = AutoServerSelector(policy: .production, healthStore: store, bootstrapper: bootstrap)

        let run = await selector.select(request)

        #expect(run.statistics.candidateCount == 4)
        #expect(run.statistics.startedCount == 4)
        #expect(run.statistics.neverStartedCount == 0)
    }

    @Test func select_concurrencyRespectsLimit() async {
        let servers = (0..<8).map { makeServer("S\($0)", host: "1.1.1.\($0)") }
        let bootstrap = FakeServerBootstrapping()
        await bootstrap.setOnBootstrap { server, _ in
            try? await Task.sleep(for: .milliseconds(20))
            return .success(ServerBootstrapResult(
                server: server, accessToken: "tok", dnsIPv4: "10.0.0.1", dnsIPv6: nil,
                metrics: ProbeMetrics(serverID: server.id, queuePosition: 0, queuedAtMs: 0, startedAtMs: 0, completedAtMs: 0,
                    dnsMs: nil, tcpConnectMs: nil, fakeHandshakeMs: nil, tlsHandshakeMs: nil, loginHTTPMs: nil, bootstrapHTTPMs: nil,
                    totalMs: 20, cancellationRequestedAtMs: nil, cancellationCompletedAtMs: nil, outcome: .success)
            ))
        }
        let (request, store) = makeRequest(servers: servers, bootstrap: bootstrap)
        let selector = AutoServerSelector(
            policy: SelectionPolicy(maximumActiveProbes: 2, selectionDeadline: .seconds(30)),
            healthStore: store,
            bootstrapper: bootstrap
        )

        let run = await selector.select(request)

        #expect(run.statistics.peakActiveProbes <= 2)
        #expect(run.statistics.candidateCount == 8)
    }

    @Test func select_stopsAtFirstWinner() async {
        let servers = [
            makeServer("Fast", host: "1.1.1.1"),
            makeServer("Slow1", host: "2.2.2.2"),
            makeServer("Slow2", host: "3.3.3.3"),
            makeServer("Slow3", host: "4.4.4.4"),
        ]
        let bootstrap = FakeServerBootstrapping()
        await bootstrap.setOnBootstrap { server, _ in
            if server.host == "1.1.1.1" {
                return .success(ServerBootstrapResult(
                    server: server, accessToken: "tok", dnsIPv4: "10.0.0.1", dnsIPv6: nil,
                    metrics: ProbeMetrics(serverID: server.id, queuePosition: 0, queuedAtMs: 0, startedAtMs: 0, completedAtMs: 0,
                        dnsMs: nil, tcpConnectMs: nil, fakeHandshakeMs: nil, tlsHandshakeMs: nil, loginHTTPMs: nil, bootstrapHTTPMs: nil,
                        totalMs: 10, cancellationRequestedAtMs: nil, cancellationCompletedAtMs: nil, outcome: .success)
                ))
            }
            try? await Task.sleep(for: .milliseconds(100))
            return .success(ServerBootstrapResult(
                server: server, accessToken: "tok", dnsIPv4: "10.0.0.1", dnsIPv6: nil,
                metrics: ProbeMetrics(serverID: server.id, queuePosition: 0, queuedAtMs: 0, startedAtMs: 0, completedAtMs: 0,
                    dnsMs: nil, tcpConnectMs: nil, fakeHandshakeMs: nil, tlsHandshakeMs: nil, loginHTTPMs: nil, bootstrapHTTPMs: nil,
                    totalMs: 100, cancellationRequestedAtMs: nil, cancellationCompletedAtMs: nil, outcome: .success)
            ))
        }
        let (request, store) = makeRequest(servers: servers, bootstrap: bootstrap)
        let selector = AutoServerSelector(policy: .production, healthStore: store, bootstrapper: bootstrap)

        let run = await selector.select(request)

        if case .success(let winner) = run.result {
            #expect(winner.server.host == "1.1.1.1")
        } else {
            Issue.record("Expected success")
        }
        #expect(run.statistics.startedCount == 4)
        #expect(run.statistics.timeToWinnerMs ?? 0 < 50)
    }

    @Test func select_authenticationQuorum() async {
        let servers = [
            makeServer("A", host: "1.1.1.1"),
            makeServer("B", host: "2.2.2.2"),
            makeServer("C", host: "3.3.3.3"),
        ]
        let bootstrap = FakeServerBootstrapping()
        await bootstrap.setOnBootstrap { _, _ in
            return .failure(ServerProbeFailure(
                server: servers[0], kind: .authenticationRejected,
                metrics: ProbeMetrics(serverID: "x", queuePosition: 0, queuedAtMs: 0, startedAtMs: 0, completedAtMs: 0,
                    dnsMs: nil, tcpConnectMs: nil, fakeHandshakeMs: nil, tlsHandshakeMs: nil, loginHTTPMs: nil, bootstrapHTTPMs: nil,
                    totalMs: 0, cancellationRequestedAtMs: nil, cancellationCompletedAtMs: nil, outcome: .failure),
                safeDiagnostic: "401"
            ))
        }
        let (request, store) = makeRequest(servers: servers, bootstrap: bootstrap)
        let selector = AutoServerSelector(policy: .production, healthStore: store, bootstrapper: bootstrap)

        let run = await selector.select(request)

        if case .authenticationRejected = run.result {
        } else {
            Issue.record("Expected .authenticationRejected, got \(run.result)")
        }
    }

    @Test func select_cancelledNotRecordedAsFailure() async {
        let servers = [
            makeServer("A", host: "1.1.1.1"),
            makeServer("B", host: "2.2.2.2"),
        ]
        let bootstrap = FakeServerBootstrapping()
        await bootstrap.setOnBootstrap { server, _ in
            try? await Task.sleep(for: .milliseconds(50))
            return .success(ServerBootstrapResult(
                server: server, accessToken: "tok", dnsIPv4: "10.0.0.1", dnsIPv6: nil,
                metrics: ProbeMetrics(serverID: server.id, queuePosition: 0, queuedAtMs: 0, startedAtMs: 0, completedAtMs: 0,
                    dnsMs: nil, tcpConnectMs: nil, fakeHandshakeMs: nil, tlsHandshakeMs: nil, loginHTTPMs: nil, bootstrapHTTPMs: nil,
                    totalMs: 50, cancellationRequestedAtMs: nil, cancellationCompletedAtMs: nil, outcome: .success)
            ))
        }
        let (request, store) = makeRequest(servers: servers, bootstrap: bootstrap)
        let selector = AutoServerSelector(
            policy: SelectionPolicy(maximumActiveProbes: 1, selectionDeadline: .milliseconds(10)),
            healthStore: store,
            bootstrapper: bootstrap
        )

        let run = await selector.select(request)

        let cancelledObs = run.observations.filter { $0.outcome == .cancelled }
        let stored = await store.records
        for (_, record) in stored {
            #expect(record.consecutiveFailures == 0)
        }
        #expect(cancelledObs.count == 0)
    }

    @Test func scanAll_startsEveryCandidate() async {
        let servers = [
            makeServer("A", host: "1.1.1.1"),
            makeServer("B", host: "2.2.2.2"),
            makeServer("C", host: "3.3.3.3"),
            makeServer("D", host: "4.4.4.4"),
        ]
        let bootstrap = FakeServerBootstrapping()
        await bootstrap.setOnBootstrap { server, _ in
            if server.host == "1.1.1.1" {
                return .success(ServerBootstrapResult(
                    server: server, accessToken: "tok", dnsIPv4: "10.0.0.1", dnsIPv6: nil,
                    metrics: ProbeMetrics(serverID: server.id, queuePosition: 0, queuedAtMs: 0, startedAtMs: 0, completedAtMs: 0,
                        dnsMs: nil, tcpConnectMs: nil, fakeHandshakeMs: nil, tlsHandshakeMs: nil, loginHTTPMs: nil, bootstrapHTTPMs: nil,
                        totalMs: 10, cancellationRequestedAtMs: nil, cancellationCompletedAtMs: nil, outcome: .success)
                ))
            }
            try? await Task.sleep(for: .milliseconds(20))
            return .success(ServerBootstrapResult(
                server: server, accessToken: "tok", dnsIPv4: "10.0.0.1", dnsIPv6: nil,
                metrics: ProbeMetrics(serverID: server.id, queuePosition: 0, queuedAtMs: 0, startedAtMs: 0, completedAtMs: 0,
                    dnsMs: nil, tcpConnectMs: nil, fakeHandshakeMs: nil, tlsHandshakeMs: nil, loginHTTPMs: nil, bootstrapHTTPMs: nil,
                    totalMs: 20, cancellationRequestedAtMs: nil, cancellationCompletedAtMs: nil, outcome: .success)
            ))
        }
        let store = InMemoryHealthStore()
        let runner = FullScanRunner(healthStore: store, bootstrapper: bootstrap)

        let report = await runner.scan(
            servers: servers,
            credentials: Credentials(username: "u", password: "p"),
            context: makeContext(),
            bootstrapPolicy: .production,
            maxActive: 2
        )

        #expect(report.statistics.candidateCount == 4)
        #expect(report.statistics.startedCount == 4)
        #expect(report.statistics.completedCount == 4)
        #expect(report.statistics.neverStartedCount == 0)
    }

    @Test func candidateOrderer_sortsByHealthRank() async {
        let servers = [
            makeServer("A", host: "1.1.1.1"),
            makeServer("B", host: "2.2.2.2"),
            makeServer("C", host: "3.3.3.3"),
        ]
        let context = makeContext()
        let store = InMemoryHealthStore()
        let keyB = ServerHealthKey(
            serverID: servers[1].id, networkClass: context.networkClass, sni: context.sni,
            censorshipStrategy: context.censorshipStrategy,
            ipv6Available: context.ipv6Available, tokenConfigurationID: context.tokenConfigurationID
        )
        await store.setRecord(ServerHealthRecord(key: keyB, ewmaLatencyMs: 50), forKey: keyB)

        let ordered = await CandidateOrderer().order(servers, using: store, context: context)

        #expect(ordered.first?.id == servers[1].id)
    }
}
