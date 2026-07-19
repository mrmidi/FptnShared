/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
import FptnSharedCore

public enum RaceTermination: Sendable {
    case winner
    case allCompleted
    case selectionDeadline
    case callerCancelled
}

public struct RaceStatistics: Sendable {
    let startedCount: Int
    let completedCount: Int
    let neverStartedCount: Int
    let peakActiveProbes: Int
    let timeToWinnerMs: Int?
}

public struct RaceAttemptRecord: Sendable {
    let serverID: String
    let queuePosition: Int
    let result: ServerBootstrapAttempt
    let startedAt: ContinuousClock.Instant
    let completedAt: ContinuousClock.Instant
}

public struct RaceExecution: Sendable {
    public let winner: ServerBootstrapResult?
    public let attempts: [RaceAttemptRecord]
    public let statistics: RaceStatistics
    public let termination: RaceTermination
}
