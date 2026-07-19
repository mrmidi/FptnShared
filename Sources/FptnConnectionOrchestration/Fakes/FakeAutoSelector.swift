/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
import FptnSharedCore
import FptnServerSelection

public final class FakeAutoSelector: AutoSelecting, @unchecked Sendable {
    public var onSelect: ((SelectionRequest) async -> SelectionOutcome)?
    public private(set) var callCount = 0
    public private(set) var lastRequest: SelectionRequest?

    public init() {}

    public func select(_ request: SelectionRequest) async -> SelectionOutcome {
        callCount += 1
        lastRequest = request
        if let handler = onSelect {
            return await handler(request)
        }
        return SelectionOutcome(
            result: .networkUnavailable,
            attempts: []
        )
    }
}
