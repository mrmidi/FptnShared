/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
#if !CLI_BUILD
import FptnSharedCore
#endif

public struct SlidingWindowRace: Sendable {
    public init() {}

    public func run(
        candidates: [VPNServer],
        credentials: Credentials,
        context: BootstrapContext,
        bootstrapPolicy: BootstrapPolicy,
        selectionPolicy: SelectionPolicy,
        clock: any Clock = SystemClock(),
        bootstrapper: any ServerBootstrapping
    ) async -> RaceExecution {
        let maxActive = max(1, selectionPolicy.maximumActiveProbes)
        _ = bootstrapPolicy.candidateDeadline  // enforced per-candidate by native timeout
        _ = selectionPolicy.selectionDeadline // enforced by soft-deadline timer
        let runID = UUID()
        let clockNow = clock.now()

        guard !candidates.isEmpty else {
            return RaceExecution(
                winner: nil,
                attempts: [],
                statistics: RaceStatistics(startedCount: 0, completedCount: 0, neverStartedCount: 0, peakActiveProbes: 0, timeToWinnerMs: nil),
                termination: .allCompleted
            )
        }

        let result = await withTaskCancellationHandler(
            operation: {
                await withTaskGroup(of: RaceAttemptRecord.self) { group -> RaceExecution in
                    var index = 0
                    var activeCount = 0
                    var peakActive = 0
                    var winner: ServerBootstrapResult? = nil
                    var records: [RaceAttemptRecord] = []
                    var deadlineTriggered = false

                    let initialCount = min(maxActive, candidates.count)
                    while index < initialCount {
                        let server = candidates[index]
                        let pos = index
                        activeCount += 1
                        group.addTask {
                            let startedAt = clock.now()
                            let attempt = await bootstrapper.bootstrap(
                                server: server,
                                credentials: credentials,
                                context: context,
                                attempt: BootstrapAttemptContext(runID: runID, queuePosition: pos),
                                policy: bootstrapPolicy
                            )
                            let completedAt = clock.now()
                            return RaceAttemptRecord(
                                serverID: server.id,
                                queuePosition: pos,
                                result: attempt,
                                startedAt: startedAt,
                                completedAt: completedAt
                            )
                        }
                        index += 1
                    }
                    peakActive = activeCount

                    for await record in group {
                        activeCount -= 1
                        records.append(record)

                        if Task.isCancelled {
                            deadlineTriggered = true
                            if !group.isEmpty {
                                group.cancelAll()
                            }
                            break
                        }

                        switch record.result {
                        case .success(let bootstrap):
                            winner = bootstrap
                            group.cancelAll()
                            break

                        case .failure:
                            if index < candidates.count && !Task.isCancelled {
                                let server = candidates[index]
                                let pos = index
                                activeCount += 1
                                peakActive = max(peakActive, activeCount)
                                group.addTask {
                                    let startedAt = clock.now()
                                    let attempt = await bootstrapper.bootstrap(
                                        server: server,
                                        credentials: credentials,
                                        context: context,
                                        attempt: BootstrapAttemptContext(runID: runID, queuePosition: pos),
                                        policy: bootstrapPolicy
                                    )
                                    let completedAt = clock.now()
                                    return RaceAttemptRecord(
                                        serverID: server.id,
                                        queuePosition: pos,
                                        result: attempt,
                                        startedAt: startedAt,
                                        completedAt: completedAt
                                    )
                                }
                                index += 1
                            }
                        }

                        if winner != nil { break }
                    }

                    let neverStarted = candidates.count - index
                    let completedRecords = records.count
                    let timeToWinner: Int? = {
                        guard let winnerRecord = records.first(where: {
                            if case .success = $0.result { return true } else { return false }
                        }) else { return nil }
                        let elapsed = winnerRecord.completedAt - clockNow
                        return elapsed.millisecondsMs
                    }()

                    let termination: RaceTermination = {
                        if winner != nil { return .winner }
                        if Task.isCancelled { return deadlineTriggered ? .selectionDeadline : .callerCancelled }
                        return .allCompleted
                    }()

                    return RaceExecution(
                        winner: winner,
                        attempts: records,
                        statistics: RaceStatistics(
                            startedCount: index,
                            completedCount: completedRecords,
                            neverStartedCount: neverStarted,
                            peakActiveProbes: peakActive,
                            timeToWinnerMs: timeToWinner
                        ),
                        termination: termination
                    )
                }
            },
            onCancel: {
                // Parent task cancellation propagates through the task group
            }
        )

        return result
    }
}

private extension Duration {
    var millisecondsMs: Int {
        Int(Double(components.seconds) * 1000 + Double(components.attoseconds) / 1e15)
    }
}
