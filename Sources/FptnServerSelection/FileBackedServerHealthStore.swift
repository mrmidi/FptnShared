/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
import FptnSharedCore

public actor FileBackedServerHealthStore: ServerHealthStore {
    private let fileURL: URL
    private var records: [ServerHealthKey: ServerHealthRecord] = [:]

    public init(fileURL: URL) {
        self.fileURL = fileURL
        self.records = Self.loadFromDisk(url: fileURL)
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
        let policy = ServerHealthPolicy.production
        for update in updates {
            let key = update.key
            let current = records[key] ?? ServerHealthRecord(key: key)
            records[key] = policy.apply(observation: update.observation, to: current)
        }
        saveToDisk()
    }

    private static func loadFromDisk(url: URL) -> [ServerHealthKey: ServerHealthRecord] {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([ServerHealthRecord].self, from: data) else {
            return [:]
        }
        var map: [ServerHealthKey: ServerHealthRecord] = [:]
        for r in decoded {
            map[r.key] = r
        }
        return map
    }

    private func saveToDisk() {
        let array = Array(records.values)
        guard let data = try? JSONEncoder().encode(array) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
