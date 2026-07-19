/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
import FptnSharedCore

public enum ServerHealthOutcome: String, Sendable, Codable {
    case success
    case connectionTimeout
    case connectionRefused
    case tlsFailure
    case certificateMismatch
    case malformedResponse
    case authenticationRejected
    case rateLimited
    case serverError
    case networkUnreachable
    case cancelled
}

public struct ServerHealthObservation: Sendable, Codable {
    public let serverID: String
    public let outcome: ServerHealthOutcome
    public let totalBootstrapMs: Int?
    public let checkedAt: Date

    public init(serverID: String, outcome: ServerHealthOutcome, totalBootstrapMs: Int?, checkedAt: Date) {
        self.serverID = serverID
        self.outcome = outcome
        self.totalBootstrapMs = totalBootstrapMs
        self.checkedAt = checkedAt
    }

    public static func from(_ attempt: ServerBootstrapAttempt, checkedAt: Date = Date()) -> ServerHealthObservation {
        switch attempt {
        case .success(let result):
            return ServerHealthObservation(
                serverID: result.server.id,
                outcome: .success,
                totalBootstrapMs: result.metrics.totalMs,
                checkedAt: checkedAt
            )
        case .failure(let failure):
            let mapped: ServerHealthOutcome = {
                switch failure.kind {
                case .authenticationRejected, .authorizationRejected: return .authenticationRejected
                case .connectionTimeout: return .connectionTimeout
                case .connectionRefused: return .connectionRefused
                case .connectionReset: return .connectionRefused
                case .tlsHandshake, .fakeHandshake: return .tlsFailure
                case .certificateMismatch: return .certificateMismatch
                case .malformedLoginResponse, .malformedBootstrapResponse: return .malformedResponse
                case .rateLimited: return .rateLimited
                case .serverError: return .serverError
                case .cancelled: return .cancelled
                case .dnsResolution: return .networkUnreachable
                default: return .networkUnreachable
                }
            }()
            return ServerHealthObservation(
                serverID: failure.server.id,
                outcome: mapped,
                totalBootstrapMs: failure.metrics.totalMs,
                checkedAt: checkedAt
            )
        }
    }
}
