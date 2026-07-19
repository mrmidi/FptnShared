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

public enum TunnelStopReason: Sendable {
    case userInitiated
    case remoteClosed
    case networkLost
    case transportError(String)
    case authenticationFailed
    case unknown(String)
}

public protocol ConnectionCoordinating: Sendable {
    func connect() async -> ConnectionStartResult
    func disconnect(reason: DisconnectReason) async
    func handle(_ event: ConnectionEvent) async
    func stateSnapshot() async -> ConnectionStateSnapshot
}

public enum ConnectionStateSnapshot: Sendable, Equatable {
    case idle
    case bootstrapping
    case startingTunnel
    case connected(episodeID: ConnectionEpisodeID)
    case disconnecting
    case disconnected
    case failed(reason: String)
}
