/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
#if !CLI_BUILD
import FptnSharedCore
#endif

/// Coordinates the concurrency-limited sliding-window connection race.
/// Implemented using Swift 6 Structured Concurrency to ensure compile-time safety and Sendability.
public struct SlidingWindowRace: Sendable {
    
    public init() {}

    /// Performs a sliding-window race across the provided candidates list.
    ///
    /// - Parameters:
    ///   - candidates: The ordered list of servers to race.
    ///   - credentials: The login credentials.
    ///   - context: The current probe network and bypass strategy context.
    ///   - limit: The maximum number of simultaneous network probes allowed (defaults to 4).
    ///   - timeout: The timeout for each individual server probe (defaults to 5 seconds).
    ///   - overallTimeout: The maximum time allowed for the entire race (defaults to 30 seconds).
    ///   - probe: The probe engine implementing `ServerBootstrapProbing`.
    /// - Returns: The outcome of the selection race.
    public func run(
        candidates: [VPNServer],
        credentials: Credentials,
        context: ProbeContext,
        limit: Int = 4,
        timeout: Duration = .seconds(5),
        overallTimeout: Duration = .seconds(30),
        probe: any ServerBootstrapProbing
    ) async -> AutoSelectionResult {
        
        guard !candidates.isEmpty else {
            return .allCandidatesFailed(SelectionFailureSummary(
                attemptedCount: 0,
                failuresByKind: [:],
                representativeFailure: nil
            ))
        }

        // 1. Run the entire task group inside a parent task we can cancel
        let raceTask = Task {
            await withTaskGroup(of: ServerBootstrapAttempt.self) { group -> AutoSelectionResult in
                var index = 0
                var failures: [ServerProbeFailure] = []
                var winner: ServerBootstrapResult? = nil
                
                // Seed initial batch
                let initialCount = min(limit, candidates.count)
                while index < initialCount {
                    let server = candidates[index]
                    let pos = index
                    group.addTask {
                        await probe.probe(
                            server: server,
                            credentials: credentials,
                            context: context,
                            timeout: timeout,
                            queuePosition: pos
                        )
                    }
                    index += 1
                }
                
                // Sliding window loop
                for await attempt in group {
                    if Task.isCancelled {
                        break
                    }
                    
                    switch attempt {
                    case .success(let bootstrap):
                        winner = bootstrap
                        group.cancelAll()
                        break
                        
                    case .failure(let failure):
                        failures.append(failure)
                        
                        if index < candidates.count && !Task.isCancelled {
                            let nextServer = candidates[index]
                            let pos = index
                            group.addTask {
                                await probe.probe(
                                    server: nextServer,
                                    credentials: credentials,
                                    context: context,
                                    timeout: timeout,
                                    queuePosition: pos
                                )
                            }
                            index += 1
                        }
                    }
                    
                    if winner != nil {
                        break
                    }
                }
                
                if let result = winner {
                    return .success(result)
                }
                
                if Task.isCancelled && winner == nil {
                    return .cancelled
                }
                
                var failuresByKind: [String: Int] = [:]
                for f in failures {
                    failuresByKind[f.kind.rawValue, default: 0] += 1
                }
                
                let summary = SelectionFailureSummary(
                    attemptedCount: failures.count,
                    failuresByKind: failuresByKind,
                    representativeFailure: failures.first
                )
                return .allCandidatesFailed(summary)
            }
        }
        
        // 2. Start the overall deadline timer task
        let timerTask = Task {
            do {
                try await Task.sleep(for: overallTimeout)
                raceTask.cancel()
            } catch {}
        }
        
        // 3. Wait for the race to finish, then cleanup the timer
        let outcome = await raceTask.value
        timerTask.cancel()
        return outcome
    }
}

// Helper extension on Array
private extension Array {
    var empty: Bool { isEmpty }
}
