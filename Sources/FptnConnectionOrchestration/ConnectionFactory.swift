/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
import FptnSharedCore
import FptnServerSelection

public func makeManualCoordinator(
    deps: ManualConnectionDependencies
) -> any ManualConnectionCoordinating {
    ManualConnectionCoordinator(
        bootstrapper: deps.bootstrapper,
        tunnelController: deps.tunnelController,
        clock: deps.clock
    )
}

public func makeAutoCoordinator(
    deps: AutoConnectionDependencies
) -> any AutoConnectionCoordinating {
    AutoConnectionCoordinator(
        selector: deps.selector,
        tunnelController: deps.tunnelController,
        clock: deps.clock
    )
}

public func makeCoordinator(
    for plan: ConnectionPlan,
    manualDeps: ManualConnectionDependencies,
    autoDeps: AutoConnectionDependencies
) -> any ConnectionLifecycleCoordinating {
    switch plan {
    case .manual:
        makeManualCoordinator(deps: manualDeps)
    case .auto:
        makeAutoCoordinator(deps: autoDeps)
    }
}
