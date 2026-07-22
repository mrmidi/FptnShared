/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
import FptnSharedCore

public enum TunnelProviderConfigurationKey {
    public static let startupV1 = "tunnelStartupV1"
}

public enum PerAppTunnelMode: String, Codable, Sendable, Equatable {
    case disabled
    case allowSelected
    case excludeSelected
}

public enum TunnelControlAction: String, Codable, Sendable, Equatable {
    case setLogLevel = "set_log_level"
    case ping
    case getStatus = "get_status"
    case prepareStop = "prepare_stop"
}

public enum TunnelStopInitiator: String, Codable, Sendable, Equatable {
    case appDisconnect = "app_disconnect"
    case providerFailure = "provider_failure"
    case systemStop = "system_stop"
}

public struct TunnelControlMessage: Codable, Sendable, Equatable {
    public let action: TunnelControlAction
    public let logLevel: SharedLogLevel?
    public let initiator: TunnelStopInitiator?

    public init(action: TunnelControlAction, logLevel: SharedLogLevel? = nil, initiator: TunnelStopInitiator? = nil) {
        self.action = action
        self.logLevel = logLevel
        self.initiator = initiator
    }
}

public struct TunnelControlResponse: Codable, Sendable, Equatable {
    public let ok: Bool
    public let message: String

    public init(ok: Bool, message: String) {
        self.ok = ok
        self.message = message
    }
}

/// A compact, ephemeral app-to-provider status response used to render the
/// currently connected tunnel. It is deliberately limited to monotonic packet
/// byte counters: diagnostic history continues to live in the binary flight
/// recorder and lifecycle snapshot stores.
public struct TunnelTrafficSnapshotV1: Codable, Sendable, Equatable {
    public let outboundPacketBytes: UInt64
    public let inboundPacketBytes: UInt64

    public init(outboundPacketBytes: UInt64, inboundPacketBytes: UInt64) {
        self.outboundPacketBytes = outboundPacketBytes
        self.inboundPacketBytes = inboundPacketBytes
    }
}

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
