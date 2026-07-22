/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
import FptnSharedCore

public struct SelectionRunStatistics: Sendable, Codable {
    public let candidateCount: Int
    public let startedCount: Int
    public let completedCount: Int
    public let neverStartedCount: Int
    public let peakActiveProbes: Int
    public let timeToWinnerMs: Int?
    public let deadlineTriggered: Bool

    public init(
        candidateCount: Int,
        startedCount: Int,
        completedCount: Int,
        neverStartedCount: Int,
        peakActiveProbes: Int,
        timeToWinnerMs: Int?,
        deadlineTriggered: Bool
    ) {
        self.candidateCount = candidateCount
        self.startedCount = startedCount
        self.completedCount = completedCount
        self.neverStartedCount = neverStartedCount
        self.peakActiveProbes = peakActiveProbes
        self.timeToWinnerMs = timeToWinnerMs
        self.deadlineTriggered = deadlineTriggered
    }
}

public struct SelectionRun: Sendable {
    public let result: AutoSelectionResult
    public let observations: [ServerHealthObservation]
    public let statistics: SelectionRunStatistics
    public let selectionSource: SelectionSource

    public init(
        result: AutoSelectionResult,
        observations: [ServerHealthObservation],
        statistics: SelectionRunStatistics,
        selectionSource: SelectionSource = .liveRace
    ) {
        self.result = result
        self.observations = observations
        self.statistics = statistics
        self.selectionSource = selectionSource
    }
}

public struct SelectionRequest: Sendable {
    public let servers: [VPNServer]
    public let credentials: Credentials
    public let context: BootstrapContext
    public let bootstrapPolicy: BootstrapPolicy
    public let selectionPolicy: SelectionPolicy

    public init(
        servers: [VPNServer],
        credentials: Credentials,
        context: BootstrapContext,
        bootstrapPolicy: BootstrapPolicy = .production,
        selectionPolicy: SelectionPolicy = .production
    ) {
        self.servers = servers
        self.credentials = credentials
        self.context = context
        self.bootstrapPolicy = bootstrapPolicy
        self.selectionPolicy = selectionPolicy
    }
}
