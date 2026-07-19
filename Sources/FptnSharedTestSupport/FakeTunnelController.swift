/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
#if !CLI_BUILD
import FptnSharedCore
import FptnServerSelection
import FptnConnectionOrchestration
#endif

public actor FakeTunnelController: TunnelControlling {
    private var _onStart: ((ConnectionEpisodeID, TunnelStartupConfiguration) async -> Result<Void, TunnelStartError>)?
    private var _shouldSucceed: Bool = true
    public private(set) var startCallCount = 0
    public private(set) var stopCallCount = 0
    public private(set) var startedEpisodes: [ConnectionEpisodeID] = []
    public private(set) var stoppedEpisodes: [ConnectionEpisodeID] = []

    public init(onStart: ((ConnectionEpisodeID, TunnelStartupConfiguration) async -> Result<Void, TunnelStartError>)? = nil,
                shouldSucceed: Bool = true) {
        self._onStart = onStart
        self._shouldSucceed = shouldSucceed
    }

    public func setOnStart(_ handler: ((ConnectionEpisodeID, TunnelStartupConfiguration) async -> Result<Void, TunnelStartError>)?) {
        self._onStart = handler
    }

    public func setShouldSucceed(_ value: Bool) {
        self._shouldSucceed = value
    }

    public func start(episodeID: ConnectionEpisodeID, configuration: TunnelStartupConfiguration) async -> Result<Void, TunnelStartError> {
        startCallCount += 1
        startedEpisodes.append(episodeID)
        if let handler = _onStart {
            return await handler(episodeID, configuration)
        }
        return _shouldSucceed ? .success(()) : .failure(.refused("simulated tunnel failure"))
    }

    public func stop(episodeID: ConnectionEpisodeID) async {
        stopCallCount += 1
        stoppedEpisodes.append(episodeID)
    }
}
