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
/// currently connected tunnel: exact session traffic totals, sampled peak
/// bandwidth, and the monotonic anchors needed to interpret them. The
/// provider computes these because it keeps running (and counting) while
/// the containing app is backgrounded — only it can report a total or a
/// peak that covers time the app itself was not observing. Everything else
/// (memory, queue/lease health, lifecycle state) continues to live in the
/// binary flight recorder and lifecycle snapshot stores.
public struct TunnelTrafficSnapshotV1: Codable, Sendable, Equatable {
    /// Exact, provider-accounted cumulative bytes admitted into the outbound
    /// transport queue this tunnel session — not merely offered to the
    /// tunnel by the OS, only bytes actually accepted.
    public let sessionUploadBytes: UInt64
    /// Exact, provider-accounted cumulative bytes delivered back to the
    /// device's packet flow this tunnel session.
    public let sessionDownloadBytes: UInt64
    /// Max of the provider's periodic window-average upload rate this
    /// session, in bytes/sec.
    public let peakUploadBytesPerSecond: UInt64
    /// Max of the provider's periodic window-average download rate this
    /// session, in bytes/sec.
    public let peakDownloadBytesPerSecond: UInt64
    /// Nominal sampling interval behind the two peak fields above, in
    /// seconds. "Nominal" because the underlying dispatch timer can drift or
    /// be coalesced by the system — this is not a guaranteed exact window.
    public let peakBandwidthNominalWindowSeconds: UInt32
    /// mach_continuous_time() ticks at tunnel session start — not wall time.
    public let sessionStartMonotonicTime: UInt64
    /// mach_continuous_time() ticks when this snapshot was sampled.
    public let sampleMonotonicTime: UInt64

    public init(
        sessionUploadBytes: UInt64,
        sessionDownloadBytes: UInt64,
        peakUploadBytesPerSecond: UInt64,
        peakDownloadBytesPerSecond: UInt64,
        peakBandwidthNominalWindowSeconds: UInt32,
        sessionStartMonotonicTime: UInt64,
        sampleMonotonicTime: UInt64
    ) {
        self.sessionUploadBytes = sessionUploadBytes
        self.sessionDownloadBytes = sessionDownloadBytes
        self.peakUploadBytesPerSecond = peakUploadBytesPerSecond
        self.peakDownloadBytesPerSecond = peakDownloadBytesPerSecond
        self.peakBandwidthNominalWindowSeconds = peakBandwidthNominalWindowSeconds
        self.sessionStartMonotonicTime = sessionStartMonotonicTime
        self.sampleMonotonicTime = sampleMonotonicTime
    }
}

/// The full app-facing tunnel status returned by `getStatus`. Supersedes
/// returning a bare `TunnelTrafficSnapshotV1`: it folds the exact traffic
/// totals together with the memory, outbound-queue, packet-lease, and
/// session-identity counters the Telemetry screen previously could only read
/// from the durable binary lifecycle snapshot on a coarse ~15s cadence.
///
/// This travels on the same 1 Hz `getStatus` round-trip the app already makes
/// while foregrounded, so the live screen no longer lags the tunnel by up to
/// a snapshot interval, and the durable binary snapshot is demoted to a pure
/// "last known state after the provider dies" fallback. Only the provider can
/// report these while the app is backgrounded and not observing.
public struct TunnelStatusSnapshotV1: Codable, Sendable, Equatable {
    /// Exact session traffic totals + sampled peak bandwidth. See
    /// `TunnelTrafficSnapshotV1`.
    public let traffic: TunnelTrafficSnapshotV1

    // Memory — sampled from the provider's Mach task info, in bytes.
    public let memoryFootprintBytes: UInt64
    public let memoryResidentBytes: UInt64
    public let memoryFootprintPeakBytes: UInt64

    // Outbound transport queue + native packet-lease health.
    public let outboundQueuedBytes: UInt64
    public let outboundQueuedBytesPeak: UInt64
    public let queueFullCount: UInt64
    public let livePacketLeases: UInt64
    public let peakPacketLeases: UInt64
    public let nativeActiveOperations: UInt32

    // Session identity + recovery. `sessionToken` is a hash derived from the
    // tunnel episode identifier, not the identifier itself.
    public let sessionToken: UInt64
    public let websocketGeneration: UInt32
    public let reconnectAttempt: UInt32

    public init(
        traffic: TunnelTrafficSnapshotV1,
        memoryFootprintBytes: UInt64,
        memoryResidentBytes: UInt64,
        memoryFootprintPeakBytes: UInt64,
        outboundQueuedBytes: UInt64,
        outboundQueuedBytesPeak: UInt64,
        queueFullCount: UInt64,
        livePacketLeases: UInt64,
        peakPacketLeases: UInt64,
        nativeActiveOperations: UInt32,
        sessionToken: UInt64,
        websocketGeneration: UInt32,
        reconnectAttempt: UInt32
    ) {
        self.traffic = traffic
        self.memoryFootprintBytes = memoryFootprintBytes
        self.memoryResidentBytes = memoryResidentBytes
        self.memoryFootprintPeakBytes = memoryFootprintPeakBytes
        self.outboundQueuedBytes = outboundQueuedBytes
        self.outboundQueuedBytesPeak = outboundQueuedBytesPeak
        self.queueFullCount = queueFullCount
        self.livePacketLeases = livePacketLeases
        self.peakPacketLeases = peakPacketLeases
        self.nativeActiveOperations = nativeActiveOperations
        self.sessionToken = sessionToken
        self.websocketGeneration = websocketGeneration
        self.reconnectAttempt = reconnectAttempt
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
