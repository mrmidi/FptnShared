/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
#if !CLI_BUILD
import FptnSharedCore
import FptnServerSelection
#endif

/// Represents a simulated outcome for a specific server during a test run.
public struct SimulatedOutcome: Sendable, Codable {
    public let delayMs: Int
    public let status: String // "success", "timeout", "auth_rejected", "server_error", etc.
    
    public init(delayMs: Int, status: String) {
        self.delayMs = delayMs
        self.status = status
    }
}

/// A fake implementation of `ServerBootstrapProbing` used for simulation runs and unit testing.
/// Supports deterministic timing and outcomes for each server.
public final class FakeServerBootstrapProbe: ServerBootstrapProbing, @unchecked Sendable {
    private let simulatedOutcomes: [String: SimulatedOutcome]
    
    /// Initializes the fake probe with a dictionary of server ID -> simulated outcome.
    public init(simulatedOutcomes: [String: SimulatedOutcome]) {
        self.simulatedOutcomes = simulatedOutcomes
    }
    
    public func probe(
        server: VPNServer,
        credentials: Credentials,
        context: ProbeContext,
        timeout: Duration,
        queuePosition: Int
    ) async -> ServerBootstrapAttempt {
        let queuedAt = Int64(Date().timeIntervalSince1970 * 1000)
        let startedAt = queuedAt
        
        // Find simulated outcome or fallback to a default success in 200ms
        let outcome = simulatedOutcomes[server.name] ?? simulatedOutcomes[server.host] ?? SimulatedOutcome(delayMs: 200, status: "success")
        
        let delay = Duration.milliseconds(outcome.delayMs)
        
        do {
            // Sleep for the simulated delay duration to mimic network traffic
            try await Task.sleep(for: delay)
        } catch {
            // Task was cancelled during sleep (cancellation propagation)
            let endedAt = Int64(Date().timeIntervalSince1970 * 1000)
            let metrics = ProbeMetrics(
                serverID: server.id,
                queuePosition: queuePosition,
                queuedAtMs: queuedAt,
                startedAtMs: startedAt,
                completedAtMs: endedAt,
                dnsMs: 10,
                tcpConnectMs: 20,
                fakeHandshakeMs: nil,
                tlsHandshakeMs: nil,
                loginHTTPMs: nil,
                bootstrapHTTPMs: nil,
                totalMs: Int(endedAt - startedAt),
                cancellationRequestedAtMs: endedAt,
                cancellationCompletedAtMs: endedAt,
                outcome: .cancelled
            )
            return .failure(ServerProbeFailure(
                server: server,
                kind: .cancelled,
                metrics: metrics,
                safeDiagnostic: "Probe cancelled cooperatively."
            ))
        }
        
        let endedAt = Int64(Date().timeIntervalSince1970 * 1000)
        
        let metrics = ProbeMetrics(
            serverID: server.id,
            queuePosition: queuePosition,
            queuedAtMs: queuedAt,
            startedAtMs: startedAt,
            completedAtMs: endedAt,
            dnsMs: 15,
            tcpConnectMs: 35,
            fakeHandshakeMs: outcome.status == "success" ? 150 : nil,
            tlsHandshakeMs: outcome.status == "success" ? 120 : nil,
            loginHTTPMs: outcome.status == "success" ? 180 : nil,
            bootstrapHTTPMs: outcome.status == "success" ? 100 : nil,
            totalMs: Int(endedAt - startedAt),
            cancellationRequestedAtMs: nil,
            cancellationCompletedAtMs: nil,
            outcome: outcome.status == "success" ? .success : .failure
        )
        
        if outcome.status == "success" {
            return .success(ServerBootstrapResult(
                server: server,
                accessToken: "simulated_token_\(server.name)",
                dnsIPv4: "1.1.1.1",
                dnsIPv6: nil,
                metrics: metrics
            ))
        } else {
            let failureKind: ServerProbeFailureKind
            switch outcome.status {
            case "timeout":
                failureKind = .connectionTimeout
            case "authentication_rejected", "auth_rejected":
                failureKind = .authenticationRejected
            case "server_error":
                failureKind = .serverError
            default:
                failureKind = .nativeFailure
            }
            
            return .failure(ServerProbeFailure(
                server: server,
                kind: failureKind,
                metrics: metrics,
                safeDiagnostic: "Simulated failure: \(outcome.status)"
            ))
        }
    }
}
