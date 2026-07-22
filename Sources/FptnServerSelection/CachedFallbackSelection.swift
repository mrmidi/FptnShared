/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
import FptnSharedCore

public enum SelectionSource: Sendable, Codable, Equatable {
    case liveRace
    case cachedCandidateBootstrap
}

public actor CachedFallbackSelection {
    private let healthStore: ServerHealthStore
    private let bootstrapper: any ServerBootstrapping
    private let clock: any Clock

    public init(
        healthStore: ServerHealthStore,
        bootstrapper: any ServerBootstrapping,
        clock: any Clock = SystemClock()
    ) {
        self.healthStore = healthStore
        self.bootstrapper = bootstrapper
        self.clock = clock
    }

    public func fallbackBootstrap(
        candidates: [VPNServer],
        credentials: Credentials,
        context: BootstrapContext,
        bootstrapPolicy: BootstrapPolicy,
        executedAttempts: [RaceAttemptRecord],
        budget: Duration
    ) async -> ServerBootstrapResult? {
        guard budget > .zero else { return nil }

        // Find candidate IDs that suffered terminal (non-cancelled) failures during the live race
        let terminalFailedServerIDs = Set(executedAttempts.compactMap { record -> String? in
            if case .failure(let f) = record.result, f.kind != .cancelled {
                return record.serverID
            }
            return nil
        })

        // Re-order candidates using stored health metrics
        let ordered = await CandidateOrderer().order(candidates, using: healthStore, context: context)

        // Select the top candidate that didn't experience a terminal failure
        guard let bestCandidate = ordered.first(where: { !terminalFailedServerIDs.contains($0.id) }) else {
            return nil
        }

        // Apply remaining budget as stage and candidate deadline
        var fallbackPolicy = bootstrapPolicy
        let cappedTimeout = min(bootstrapPolicy.candidateDeadline, budget)

        let runID = UUID()
        let attempt = await bootstrapper.bootstrap(
            server: bestCandidate,
            credentials: credentials,
            context: context,
            attempt: BootstrapAttemptContext(runID: runID, queuePosition: 0),
            policy: BootstrapPolicy(
                loginAttempts: 1,
                dnsAttempts: 1,
                stageTimeout: cappedTimeout,
                candidateDeadline: cappedTimeout
            )
        )

        if case .success(let result) = attempt {
            return result
        }
        return nil
    }
}
