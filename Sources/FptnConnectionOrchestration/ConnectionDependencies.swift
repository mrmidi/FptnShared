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
    func stop() async
}

public struct ConnectionDependencies {
    public let nativeBootstrap: any ServerBootstrapping
    public let autoSelector: any AutoSelecting
    public let tunnelController: any TunnelControlling
    public let clock: any Clock

    public init(
        nativeBootstrap: any ServerBootstrapping,
        autoSelector: any AutoSelecting,
        tunnelController: any TunnelControlling,
        clock: any Clock = SystemClock()
    ) {
        self.nativeBootstrap = nativeBootstrap
        self.autoSelector = autoSelector
        self.tunnelController = tunnelController
        self.clock = clock
    }
}
