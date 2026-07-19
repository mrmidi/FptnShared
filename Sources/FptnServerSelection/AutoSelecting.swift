/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
import FptnSharedCore

public struct SelectionRequest: Sendable {
    public let servers: [VPNServer]
    public let credentials: Credentials
    public let context: BootstrapContext
    public let policy: BootstrapPolicy

    public init(
        servers: [VPNServer],
        credentials: Credentials,
        context: BootstrapContext,
        policy: BootstrapPolicy
    ) {
        self.servers = servers
        self.credentials = credentials
        self.context = context
        self.policy = policy
    }
}

public struct SelectionOutcome: Sendable {
    public let result: AutoSelectionResult
    public let attempts: [ServerBootstrapAttempt]

    public init(result: AutoSelectionResult, attempts: [ServerBootstrapAttempt]) {
        self.result = result
        self.attempts = attempts
    }
}

public protocol AutoSelecting: Sendable {
    func select(_ request: SelectionRequest) async -> SelectionOutcome
}
