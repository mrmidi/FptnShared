/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
import FptnSharedCore

public struct CandidateOrderer: Sendable {
    public init() {}

    public func order(
        _ servers: [VPNServer],
        using healthStore: ServerHealthStore,
        context: BootstrapContext
    ) async -> [VPNServer] {
        let keys = servers.map { server in
            ServerHealthKey(
                serverID: server.id,
                networkClass: context.networkClass,
                sni: context.sni,
                censorshipStrategy: context.censorshipStrategy,
                ipv6Available: context.ipv6Available,
                tokenConfigurationID: context.tokenConfigurationID
            )
        }

        let records: [ServerHealthKey: ServerHealthRecord]
        do {
            records = try await healthStore.load(for: keys)
        } catch {
            return servers
        }

        let now = Date()
        return servers.sorted { s1, s2 in
            let k1 = ServerHealthKey(
                serverID: s1.id, networkClass: context.networkClass,
                sni: context.sni, censorshipStrategy: context.censorshipStrategy,
                ipv6Available: context.ipv6Available, tokenConfigurationID: context.tokenConfigurationID
            )
            let k2 = ServerHealthKey(
                serverID: s2.id, networkClass: context.networkClass,
                sni: context.sni, censorshipStrategy: context.censorshipStrategy,
                ipv6Available: context.ipv6Available, tokenConfigurationID: context.tokenConfigurationID
            )
            let r1 = records[k1]
            let r2 = records[k2]

            let cd1 = r1?.cooldownUntil
            let cd2 = r2?.cooldownUntil
            let inCooldown1 = cd1.map { $0 > now } ?? false
            let inCooldown2 = cd2.map { $0 > now } ?? false

            if inCooldown1 != inCooldown2 {
                return !inCooldown1
            }

            let lat1 = r1?.ewmaLatencyMs ?? 1000
            let lat2 = r2?.ewmaLatencyMs ?? 1000

            if lat1 != lat2 {
                return lat1 < lat2
            }

            return s1.name.localizedCaseInsensitiveCompare(s2.name) == .orderedAscending
        }
    }
}
