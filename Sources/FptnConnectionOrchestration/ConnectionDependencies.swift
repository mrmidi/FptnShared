/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
import FptnSharedCore
import FptnSharedTunnel
import FptnServerSelection

public typealias Clock = FptnSharedCore.Clock
public typealias SystemClock = FptnSharedCore.SystemClock

public enum TunnelStartError: Error, Sendable {
    case refused(String)
}

public protocol TunnelControlling: Sendable {
    func start(episodeID: ConnectionEpisodeID, configuration: TunnelStartupConfigurationV1) async -> Result<Void, TunnelStartError>
    func stop(episodeID: ConnectionEpisodeID, initiator: TunnelStopInitiator) async
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
