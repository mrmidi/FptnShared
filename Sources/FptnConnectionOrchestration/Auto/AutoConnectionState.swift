/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
import FptnSharedCore

public enum AutoConnectionState: Sendable, Equatable {
    case idle
    case selecting
    case startingTunnel
    case connected(ConnectionEpisodeID)
    case disconnecting
    case waitingForNetwork
    case retryingCurrentServer
    case selectingReplacement
    case handingOff
    case stabilizing
    case exhausted
    case failed(AutoConnectionFailure)
}

public enum AutoConnectionFailure: Sendable, Equatable {
    case noServersAvailable
    case allExhausted
    case authenticationRejected
    case networkUnavailable
    case internalError(String)
}
