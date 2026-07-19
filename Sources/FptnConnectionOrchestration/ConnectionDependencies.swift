/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
import FptnSharedCore
import FptnServerSelection

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

public enum TunnelStartError: Error, Sendable {
    case refused(String)
}

public protocol TunnelControlling: Sendable {
    func start(episodeID: ConnectionEpisodeID, configuration: TunnelStartupConfiguration) async -> Result<Void, TunnelStartError>
    func stop(episodeID: ConnectionEpisodeID) async
}

public struct ManualConnectionDependencies {
    public let bootstrapper: any ServerBootstrapping
    public let tunnelController: any TunnelControlling
    public let clock: any Clock

    public init(
        bootstrapper: any ServerBootstrapping,
        tunnelController: any TunnelControlling,
        clock: any Clock = SystemClock()
    ) {
        self.bootstrapper = bootstrapper
        self.tunnelController = tunnelController
        self.clock = clock
    }
}

public struct AutoConnectionDependencies {
    public let selector: any AutoSelecting
    public let tunnelController: any TunnelControlling
    public let clock: any Clock

    public init(
        selector: any AutoSelecting,
        tunnelController: any TunnelControlling,
        clock: any Clock = SystemClock()
    ) {
        self.selector = selector
        self.tunnelController = tunnelController
        self.clock = clock
    }
}
