/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
#if !CLI_BUILD
import FptnSharedCore
import FptnServerSelection
#endif

public actor FakeAutoSelector: AutoSelecting {
    private var _onSelect: ((SelectionRequest) async -> SelectionRun)?
    public private(set) var callCount = 0
    public private(set) var lastRequest: SelectionRequest?

    public init(onSelect: ((SelectionRequest) async -> SelectionRun)? = nil) {
        self._onSelect = onSelect
    }

    public func setOnSelect(_ handler: ((SelectionRequest) async -> SelectionRun)?) {
        self._onSelect = handler
    }

    public func select(_ request: SelectionRequest) async -> SelectionRun {
        callCount += 1
        lastRequest = request
        if let handler = _onSelect {
            return await handler(request)
        }
        return SelectionRun(
            result: .networkUnavailable,
            observations: [],
            statistics: SelectionRunStatistics(
                candidateCount: request.servers.count,
                startedCount: 0,
                completedCount: 0,
                neverStartedCount: request.servers.count,
                peakActiveProbes: 0,
                timeToWinnerMs: nil,
                deadlineTriggered: false
            )
        )
    }
}
