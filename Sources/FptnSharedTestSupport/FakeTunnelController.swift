/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
import FptnSharedCore
import FptnSharedTunnel
import FptnServerSelection
import FptnConnectionOrchestration

public actor FakeTunnelController: TunnelControlling {
    private var _onStart: ((ConnectionEpisodeID, TunnelStartupConfigurationV1) async -> Result<Void, TunnelStartError>)?
    private var _shouldSucceed: Bool = true
    public private(set) var startCallCount = 0
    public private(set) var stopCallCount = 0
    public private(set) var startedEpisodes: [ConnectionEpisodeID] = []
    public private(set) var stoppedEpisodes: [ConnectionEpisodeID] = []
    public private(set) var stoppedInitiators: [TunnelStopInitiator] = []
    public private(set) var lastStartupConfiguration: TunnelStartupConfigurationV1?

    public init(
        onStart: ((ConnectionEpisodeID, TunnelStartupConfigurationV1) async -> Result<Void, TunnelStartError>)? = nil,
        shouldSucceed: Bool = true
    ) {
        self._onStart = onStart
        self._shouldSucceed = shouldSucceed
    }

    public func setOnStart(_ handler: ((ConnectionEpisodeID, TunnelStartupConfigurationV1) async -> Result<Void, TunnelStartError>)?) {
        self._onStart = handler
    }

    public func setShouldSucceed(_ value: Bool) {
        self._shouldSucceed = value
    }

    public func start(episodeID: ConnectionEpisodeID, configuration: TunnelStartupConfigurationV1) async -> Result<Void, TunnelStartError> {
        startCallCount += 1
        startedEpisodes.append(episodeID)
        lastStartupConfiguration = configuration
        if let handler = _onStart {
            return await handler(episodeID, configuration)
        }
        return _shouldSucceed ? .success(()) : .failure(.refused("simulated tunnel failure"))
    }

    public func stop(episodeID: ConnectionEpisodeID, initiator: TunnelStopInitiator) async {
        stopCallCount += 1
        stoppedEpisodes.append(episodeID)
        stoppedInitiators.append(initiator)
    }
}
