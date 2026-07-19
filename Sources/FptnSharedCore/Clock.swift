/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation

public protocol Clock: Sendable {
    func now() -> ContinuousClock.Instant
    func sleep(for duration: Duration) async throws
}

public struct SystemClock: Clock {
    public init() {}
    public func now() -> ContinuousClock.Instant { ContinuousClock.now }
    public func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}
