/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation

public enum TunnelRecoveryPolicy: Codable, Sendable, Equatable {
    case none
    case automatic(AutoTunnelRecoveryPolicy)
}

public struct AutoTunnelRecoveryPolicy: Codable, Sendable, Equatable {
    public let sameServerAttempts: Int
    public let reconnectDelaySeconds: Int

    public init(sameServerAttempts: Int, reconnectDelaySeconds: Int) {
        self.sameServerAttempts = sameServerAttempts
        self.reconnectDelaySeconds = reconnectDelaySeconds
    }
}
