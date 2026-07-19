/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
import FptnSharedCore
import FptnServerSelection

public final class FakeTunnelController: TunnelControlling, @unchecked Sendable {
    public var onStart: ((ConnectionEpisodeID, TunnelStartupConfiguration) async -> Result<Void, TunnelStartError>)?
    public private(set) var startCallCount = 0
    public private(set) var stopCallCount = 0
    public private(set) var startedEpisodes: [ConnectionEpisodeID] = []
    public var shouldSucceed: Bool = true

    public init() {}

    public func start(episodeID: ConnectionEpisodeID, configuration: TunnelStartupConfiguration) async -> Result<Void, TunnelStartError> {
        startCallCount += 1
        startedEpisodes.append(episodeID)
        if let handler = onStart {
            return await handler(episodeID, configuration)
        }
        return shouldSucceed ? .success(()) : .failure(.refused("simulated tunnel failure"))
    }

    public func stop() async {
        stopCallCount += 1
    }
}
