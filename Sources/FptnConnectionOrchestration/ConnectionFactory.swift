/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
import FptnSharedCore
import FptnServerSelection

public func makeCoordinator(
    for intent: ConnectionIntent,
    deps: ConnectionDependencies
) -> any ConnectionCoordinating {
    switch intent {
    case .manual(let server):
        ManualConnectionCoordinator(
            server: server,
            bootstrapper: deps.nativeBootstrap,
            tunnelController: deps.tunnelController,
            clock: deps.clock
        )
    case .auto:
        AutoConnectionCoordinator(
            selector: deps.autoSelector,
            tunnelController: deps.tunnelController,
            clock: deps.clock
        )
    }
}
