/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation

/// Represents the outcome classification of a probe.
public enum ProbeMetricOutcome: String, Codable, Sendable, Hashable {
    case success
    case failure
    case cancelled
}

/// Contains timing and execution metrics for a single server connection attempt.
/// Units are in milliseconds from the start of the connection attempt or epoch offset.
public struct ProbeMetrics: Codable, Sendable, Hashable {
    public let serverID: String
    public let queuePosition: Int

    public let queuedAtMs: Int64
    public let startedAtMs: Int64
    public let completedAtMs: Int64

    public let dnsMs: Int?
    public let tcpConnectMs: Int?
    public let fakeHandshakeMs: Int?
    public let tlsHandshakeMs: Int?
    public let loginHTTPMs: Int?
    public let bootstrapHTTPMs: Int?
    public let totalMs: Int

    public let cancellationRequestedAtMs: Int64?
    public let cancellationCompletedAtMs: Int64?

    public let outcome: ProbeMetricOutcome

    public init(
        serverID: String,
        queuePosition: Int,
        queuedAtMs: Int64,
        startedAtMs: Int64,
        completedAtMs: Int64,
        dnsMs: Int?,
        tcpConnectMs: Int?,
        fakeHandshakeMs: Int?,
        tlsHandshakeMs: Int?,
        loginHTTPMs: Int?,
        bootstrapHTTPMs: Int?,
        totalMs: Int,
        cancellationRequestedAtMs: Int64?,
        cancellationCompletedAtMs: Int64?,
        outcome: ProbeMetricOutcome
    ) {
        self.serverID = serverID
        self.queuePosition = queuePosition
        self.queuedAtMs = queuedAtMs
        self.startedAtMs = startedAtMs
        self.completedAtMs = completedAtMs
        self.dnsMs = dnsMs
        self.tcpConnectMs = tcpConnectMs
        self.fakeHandshakeMs = fakeHandshakeMs
        self.tlsHandshakeMs = tlsHandshakeMs
        self.loginHTTPMs = loginHTTPMs
        self.bootstrapHTTPMs = bootstrapHTTPMs
        self.totalMs = totalMs
        self.cancellationRequestedAtMs = cancellationRequestedAtMs
        self.cancellationCompletedAtMs = cancellationCompletedAtMs
        self.outcome = outcome
    }
}

/// Classifies the technical reason why a server probe failed.
public enum ServerProbeFailureKind: String, Codable, Sendable, Hashable {
    case cancelled

    case dnsResolution
    case connectionRefused
    case connectionTimeout
    case connectionReset

    case fakeHandshake
    case tlsHandshake
    case certificateMismatch

    case authenticationRejected
    case authorizationRejected
    case rateLimited
    case serverError

    case malformedLoginResponse
    case malformedBootstrapResponse
    case unsupportedProtocol

    case nativeFailure
    case overallDeadline
}

/// Returned when a server probe fails.
public struct ServerProbeFailure: Sendable, Codable, Hashable {
    public let server: VPNServer
    public let kind: ServerProbeFailureKind
    public let metrics: ProbeMetrics
    public let safeDiagnostic: String?

    public init(
        server: VPNServer,
        kind: ServerProbeFailureKind,
        metrics: ProbeMetrics,
        safeDiagnostic: String? = nil
    ) {
        self.server = server
        self.kind = kind
        self.metrics = metrics
        self.safeDiagnostic = safeDiagnostic
    }
}

/// Returned when a server successfully completes all bootstrap phases.
public struct ServerBootstrapResult: Sendable, Codable, Hashable {
    public let server: VPNServer
    public let accessToken: String
    public let dnsIPv4: String
    public let dnsIPv6: String?
    public let metrics: ProbeMetrics

    public init(
        server: VPNServer,
        accessToken: String,
        dnsIPv4: String,
        dnsIPv6: String?,
        metrics: ProbeMetrics
    ) {
        self.server = server
        self.accessToken = accessToken
        self.dnsIPv4 = dnsIPv4
        self.dnsIPv6 = dnsIPv6
        self.metrics = metrics
    }
}

/// The result of a single server bootstrap attempt.
public enum ServerBootstrapAttempt: Sendable {
    case success(ServerBootstrapResult)
    case failure(ServerProbeFailure)
}
