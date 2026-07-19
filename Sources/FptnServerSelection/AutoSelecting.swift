/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
import FptnSharedCore

public protocol AutoSelecting: Sendable {
    func select(_ request: SelectionRequest) async -> SelectionRun
}
