/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
import FptnSharedCore

public actor AutoServerSelector: AutoSelecting {
    private let overridePolicy: SelectionPolicy?
    private let healthStore: ServerHealthStore
    private let healthPolicy: ServerHealthPolicy
    private let bootstrapper: any ServerBootstrapping
    private let clock: any Clock

    public init(
        policy: SelectionPolicy? = nil,
        healthStore: ServerHealthStore,
        healthPolicy: ServerHealthPolicy = .production,
        bootstrapper: any ServerBootstrapping,
        clock: any Clock = SystemClock()
    ) {
        self.overridePolicy = policy
        self.healthStore = healthStore
        self.healthPolicy = healthPolicy
        self.bootstrapper = bootstrapper
        self.clock = clock
    }

    public func select(_ request: SelectionRequest) async -> SelectionRun {
        let activePolicy = overridePolicy ?? request.selectionPolicy
        let startTime = clock.now()
        let ordered = await CandidateOrderer().order(request.servers, using: healthStore, context: request.context)

        let race = SlidingWindowRace()
        var execution = await race.run(
            candidates: ordered,
            credentials: request.credentials,
            context: request.context,
            bootstrapPolicy: request.bootstrapPolicy,
            selectionPolicy: activePolicy,
            clock: clock,
            bootstrapper: bootstrapper
        )

        var selectionSource: SelectionSource = .liveRace

        if execution.winner == nil && execution.termination == .selectionDeadline {
            let elapsedTime = clock.now() - startTime
            let remainingBudget = activePolicy.overallSelectionDeadline - elapsedTime
            if remainingBudget > .zero {
                let fallback = CachedFallbackSelection(
                    healthStore: healthStore,
                    bootstrapper: bootstrapper,
                    clock: clock
                )
                if let fallbackWinner = await fallback.fallbackBootstrap(
                    candidates: request.servers,
                    credentials: request.credentials,
                    context: request.context,
                    bootstrapPolicy: request.bootstrapPolicy,
                    executedAttempts: execution.attempts,
                    budget: remainingBudget
                ) {
                    execution = RaceExecution(
                        winner: fallbackWinner,
                        attempts: execution.attempts,
                        statistics: execution.statistics,
                        termination: .winner
                    )
                    selectionSource = .cachedCandidateBootstrap
                }
            }
        }

        let observations = execution.attempts.map { ServerHealthObservation.from($0.result) }
        let result = aggregateOutcome(execution, observations: observations, policy: activePolicy)

        let updates = healthPolicy.updates(from: observations)
        if !updates.isEmpty {
            try? await healthStore.apply(updates)
        }

        return SelectionRun(
            result: result,
            observations: observations,
            statistics: SelectionRunStatistics(
                candidateCount: ordered.count,
                startedCount: execution.statistics.startedCount,
                completedCount: execution.statistics.completedCount,
                neverStartedCount: execution.statistics.neverStartedCount,
                peakActiveProbes: execution.statistics.peakActiveProbes,
                timeToWinnerMs: execution.statistics.timeToWinnerMs,
                deadlineTriggered: execution.termination == .selectionDeadline
            ),
            selectionSource: selectionSource
        )
    }

    private func aggregateOutcome(
        _ execution: RaceExecution,
        observations: [ServerHealthObservation],
        policy: SelectionPolicy
    ) -> AutoSelectionResult {
        if let winner = execution.winner {
            return .success(winner)
        }

        let authCount = observations.filter {
            $0.outcome == .authenticationRejected
        }.count
        if authCount >= policy.authenticationQuorum {
            return .authenticationRejected
        }

        let rateCount = observations.filter { $0.outcome == .rateLimited }.count
        if rateCount >= policy.rateLimitQuorum {
            return .rateLimited(retryAfterSeconds: nil)
        }

        let allNetwork = observations.allSatisfy {
            [.connectionTimeout, .connectionRefused, .networkUnreachable, .tlsFailure, .cancelled].contains($0.outcome)
        }
        if allNetwork && !observations.isEmpty {
            return .networkUnavailable
        }

        if execution.termination == .callerCancelled {
            return .cancelled
        }

        var failuresByKind: [String: Int] = [:]
        for record in execution.attempts {
            if case .failure(let failure) = record.result {
                failuresByKind[failure.kind.rawValue, default: 0] += 1
            }
        }

        let summary = SelectionFailureSummary(
            attemptedCount: execution.attempts.count,
            failuresByKind: failuresByKind,
            representativeFailure: execution.attempts.first.map { $0.result.failure } ?? nil
        )
        return .allCandidatesFailed(summary)
    }
}

private extension ServerBootstrapAttempt {
    var failure: ServerProbeFailure? {
        if case .failure(let f) = self { return f } else { return nil }
    }
}
