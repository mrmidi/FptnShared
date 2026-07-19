/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
import FptnSharedCore

public struct ServerHealthPolicy: Sendable {
    public let ewmaAlpha: Double
    public let failureCooldown: Duration
    public let maxConsecutiveFailures: Int

    public init(
        ewmaAlpha: Double = 0.3,
        failureCooldown: Duration = .seconds(5 * 60),
        maxConsecutiveFailures: Int = 5
    ) {
        self.ewmaAlpha = ewmaAlpha
        self.failureCooldown = failureCooldown
        self.maxConsecutiveFailures = maxConsecutiveFailures
    }

    public static let production = ServerHealthPolicy()

    public func updates(from observations: [ServerHealthObservation]) -> [ServerHealthUpdate] {
        observations.compactMap { obs in
            guard obs.outcome != .cancelled && obs.outcome != .authenticationRejected else {
                return nil
            }
            let key = ServerHealthKey(
                serverID: obs.serverID,
                networkClass: .wifi,
                sni: "",
                censorshipStrategy: CensorshipStrategy(storedValue: ""),
                ipv6Available: false,
                tokenConfigurationID: ""
            )
            return ServerHealthUpdate(key: key, observation: obs)
        }
    }

    public func apply(observation: ServerHealthObservation, to record: ServerHealthRecord) -> ServerHealthRecord {
        let now = observation.checkedAt

        switch observation.outcome {
        case .success:
            let newEwma: Double
            if let existing = record.ewmaLatencyMs, let latency = observation.totalBootstrapMs {
                newEwma = ewmaAlpha * Double(latency) + (1 - ewmaAlpha) * existing
            } else {
                newEwma = Double(observation.totalBootstrapMs ?? 0)
            }
            return ServerHealthRecord(
                key: record.key,
                ewmaLatencyMs: newEwma,
                consecutiveFailures: 0,
                lastSuccessAt: now,
                lastFailureAt: record.lastFailureAt,
                cooldownUntil: nil
            )

        case .cancelled, .authenticationRejected:
            return record

        default:
            let failures = record.consecutiveFailures + 1
            let cooldown = failures >= maxConsecutiveFailures ? now.addingTimeInterval(TimeInterval(failureCooldown.components.seconds)) : nil
            return ServerHealthRecord(
                key: record.key,
                ewmaLatencyMs: record.ewmaLatencyMs,
                consecutiveFailures: failures,
                lastSuccessAt: record.lastSuccessAt,
                lastFailureAt: now,
                cooldownUntil: cooldown
            )
        }
    }
}
