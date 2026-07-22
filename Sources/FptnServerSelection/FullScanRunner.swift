/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
import FptnSharedCore

public struct FullScanReport: Sendable {
    public let observations: [ServerHealthObservation]
    public let statistics: ScanStatistics

    public init(observations: [ServerHealthObservation], statistics: ScanStatistics) {
        self.observations = observations
        self.statistics = statistics
    }
}

public struct ScanStatistics: Sendable, Codable {
    public let candidateCount: Int
    public let startedCount: Int
    public let completedCount: Int
    public let neverStartedCount: Int
    public let peakActiveProbes: Int
    public let totalScanDurationMs: Int?

    public init(candidateCount: Int, startedCount: Int, completedCount: Int, neverStartedCount: Int, peakActiveProbes: Int, totalScanDurationMs: Int? = nil) {
        self.candidateCount = candidateCount
        self.startedCount = startedCount
        self.completedCount = completedCount
        self.neverStartedCount = neverStartedCount
        self.peakActiveProbes = peakActiveProbes
        self.totalScanDurationMs = totalScanDurationMs
    }
}

public actor FullScanRunner {
    private let healthStore: ServerHealthStore
    private let healthPolicy: ServerHealthPolicy
    private let bootstrapper: any ServerBootstrapping
    private let clock: any Clock

    public init(
        healthStore: ServerHealthStore,
        healthPolicy: ServerHealthPolicy = .production,
        bootstrapper: any ServerBootstrapping,
        clock: any Clock = SystemClock()
    ) {
        self.healthStore = healthStore
        self.healthPolicy = healthPolicy
        self.bootstrapper = bootstrapper
        self.clock = clock
    }

    public func scan(
        servers: [VPNServer],
        credentials: Credentials,
        context: BootstrapContext,
        bootstrapPolicy: BootstrapPolicy,
        maxActive: Int
    ) async -> FullScanReport {
        let ordered = await CandidateOrderer().order(servers, using: healthStore, context: context)
        let maxActive = max(1, maxActive)

        var records: [RaceAttemptRecord] = []
        var index = 0
        var peakActive = 0
        var activeCount = 0

        let runID = UUID()
        let scanStartInstant = clock.now()

        await withTaskGroup(of: RaceAttemptRecord.self) { group in
            let initialCount = min(maxActive, ordered.count)
            while index < initialCount {
                let server = ordered[index]
                let pos = index
                activeCount += 1
                group.addTask {
                    let startedAt = self.clock.now()
                    let attempt = await self.bootstrapper.bootstrap(
                        server: server,
                        credentials: credentials,
                        context: context,
                        attempt: BootstrapAttemptContext(runID: runID, queuePosition: pos),
                        policy: bootstrapPolicy
                    )
                    let completedAt = self.clock.now()
                    return RaceAttemptRecord(
                        serverID: server.id, queuePosition: pos, result: attempt,
                        startedAt: startedAt, completedAt: completedAt
                    )
                }
                index += 1
            }
            peakActive = activeCount

            for await record in group {
                activeCount -= 1
                records.append(record)

                if index < ordered.count {
                    let server = ordered[index]
                    let pos = index
                    activeCount += 1
                    peakActive = max(peakActive, activeCount)
                    group.addTask {
                        let startedAt = self.clock.now()
                        let attempt = await self.bootstrapper.bootstrap(
                            server: server,
                            credentials: credentials,
                            context: context,
                            attempt: BootstrapAttemptContext(runID: runID, queuePosition: pos),
                            policy: bootstrapPolicy
                        )
                        let completedAt = self.clock.now()
                        return RaceAttemptRecord(
                            serverID: server.id, queuePosition: pos, result: attempt,
                            startedAt: startedAt, completedAt: completedAt
                        )
                    }
                    index += 1
                }
            }
        }

        let scanEndInstant = clock.now()
        let duration = scanStartInstant.duration(to: scanEndInstant)
        let durationMs = Int(duration.components.seconds * 1000 + duration.components.attoseconds / 1_000_000_000_000_000)

        let observations = records.map { ServerHealthObservation.from($0.result) }
        let updates = healthPolicy.updates(from: observations, context: context)
        if !updates.isEmpty {
            try? await healthStore.apply(updates)
        }

        return FullScanReport(
            observations: observations,
            statistics: ScanStatistics(
                candidateCount: ordered.count,
                startedCount: index,
                completedCount: records.count,
                neverStartedCount: ordered.count - index,
                peakActiveProbes: peakActive,
                totalScanDurationMs: durationMs
            )
        )
    }
}
