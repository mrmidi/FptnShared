/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
import FptnSharedCore

public enum ConnectionStartResult: Sendable {
    case started(ConnectionEpisodeID)
    case failed(ConnectionStartFailure)
    case cancelled
}

public enum ConnectionStartFailure: Sendable, Equatable {
    case noNetwork
    case noServers
    case bootstrap(String)
    case tunnelRefused(String)
}

public enum ConnectionEvent: Sendable {
    case tunnelConnected(ConnectionEpisodeID)
    case tunnelDisconnected(ConnectionEpisodeID, TunnelStopReason)
    case networkBecameSatisfied
    case networkBecameUnsatisfied
}

public enum DisconnectReason: Sendable {
    case userInitiated
    case appTermination
}

public enum TunnelStopReason: Sendable, Equatable {
    case userInitiated
    case remoteClosed
    case networkLost
    case transportError(String)
    case authenticationFailed
    case unknown(String)
}

public protocol ConnectionLifecycleCoordinating: Sendable {
    func disconnect(reason: DisconnectReason) async
    func handle(_ event: ConnectionEvent) async
    func stateSnapshot() async -> ConnectionStateSnapshot
}

public protocol ManualConnectionCoordinating: ConnectionLifecycleCoordinating {
    func connect(_ request: ManualConnectionRequest) async -> ConnectionStartResult
}

public protocol AutoConnectionCoordinating: ConnectionLifecycleCoordinating {
    func connect(_ request: AutoConnectionRequest) async -> ConnectionStartResult
}

public enum ConnectionStateSnapshot: Sendable, Equatable {
    case idle
    case bootstrapping
    case selecting
    case startingTunnel
    case connected(episodeID: ConnectionEpisodeID)
    case disconnecting
    case disconnected
    case waitingForNetwork
    case retrying
    case selectingReplacement
    case stabilizing
    case exhausted
    case failed(reason: String)
}

public enum ConnectionPlan: Sendable {
    case manual(ManualConnectionRequest)
    case auto(AutoConnectionRequest)
}
