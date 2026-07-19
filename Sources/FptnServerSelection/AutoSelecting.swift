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
    public let observations: [ServerHealthObservation]

    public init(result: AutoSelectionResult, observations: [ServerHealthObservation]) {
        self.result = result
        self.observations = observations
    }

    public init(result: AutoSelectionResult, attempts: [ServerBootstrapAttempt]) {
        self.result = result
        self.observations = attempts.map { ServerHealthObservation.from($0) }
    }
}

public protocol AutoSelecting: Sendable {
    func select(_ request: SelectionRequest) async -> SelectionOutcome
}
