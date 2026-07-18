/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation

/// Summary of failure counts parsed by category during a connection race.
public struct SelectionFailureSummary: Sendable, Codable, Hashable {
    public let attemptedCount: Int
    public let failuresByKind: [String: Int]
    public let representativeFailure: ServerProbeFailure?

    public init(
        attemptedCount: Int,
        failuresByKind: [String: Int],
        representativeFailure: ServerProbeFailure?
    ) {
        self.attemptedCount = attemptedCount
        self.failuresByKind = failuresByKind
        self.representativeFailure = representativeFailure
    }
}

/// Represents the final resolved connection outcome of FPTN Auto Selection Mode.
public enum AutoSelectionResult: Sendable {
    /// Found a working server and completed bootstrap configuration.
    case success(ServerBootstrapResult)

    /// Global credentials rejected (401 code from quorum).
    case authenticationRejected

    /// Rate limited (429 code).
    case rateLimited(retryAfterSeconds: Int?)

    /// No network connection available.
    case networkUnavailable

    /// All tested candidate servers failed.
    case allCandidatesFailed(SelectionFailureSummary)

    /// The selection process was cancelled before completing.
    case cancelled
}
