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
    private var _onSelect: ((SelectionRequest) async -> SelectionOutcome)?
    public private(set) var callCount = 0
    public private(set) var lastRequest: SelectionRequest?

    public init(onSelect: ((SelectionRequest) async -> SelectionOutcome)? = nil) {
        self._onSelect = onSelect
    }

    public func setOnSelect(_ handler: ((SelectionRequest) async -> SelectionOutcome)?) {
        self._onSelect = handler
    }

    public func select(_ request: SelectionRequest) async -> SelectionOutcome {
        callCount += 1
        lastRequest = request
        if let handler = _onSelect {
            return await handler(request)
        }
        return SelectionOutcome(
            result: .networkUnavailable,
            attempts: []
        )
    }
}
