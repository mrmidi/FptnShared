/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
#if !CLI_BUILD
import FptnSharedCore
import FptnServerSelection
#endif

public actor InMemoryHealthStore: ServerHealthStore {
    public private(set) var records: [ServerHealthKey: ServerHealthRecord] = [:]

    public init() {}

    public func setRecord(_ record: ServerHealthRecord, forKey key: ServerHealthKey) {
        records[key] = record
    }

    public func load(for keys: [ServerHealthKey]) async throws -> [ServerHealthKey: ServerHealthRecord] {
        var result: [ServerHealthKey: ServerHealthRecord] = [:]
        for key in keys {
            if let record = records[key] {
                result[key] = record
            }
        }
        return result
    }

    public func apply(_ updates: [ServerHealthUpdate]) async throws {
        for update in updates {
            let existing = records[update.key]
            let policy = ServerHealthPolicy()
            let observation = update.observation
            if let existing {
                records[update.key] = policy.apply(observation: observation, to: existing)
            } else {
                let newRecord = ServerHealthRecord(key: update.key)
                records[update.key] = policy.apply(observation: observation, to: newRecord)
            }
        }
    }
}
