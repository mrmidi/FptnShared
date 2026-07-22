/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
import FptnSharedCore
import FptnSharedTunnel
import FptnServerSelection

public actor ManualConnectionCoordinator: ManualConnectionCoordinating {
    private let bootstrapper: any ServerBootstrapping
    private let tunnelController: any TunnelControlling
    private let clock: any Clock

    private var state: ManualConnectionState = .idle
    private var generation: UInt64 = 0
    private var activeEpisodeID: ConnectionEpisodeID?

    public init(
        bootstrapper: any ServerBootstrapping,
        tunnelController: any TunnelControlling,
        clock: any Clock = SystemClock()
    ) {
        self.bootstrapper = bootstrapper
        self.tunnelController = tunnelController
        self.clock = clock
    }

    public func connect(_ request: ManualConnectionRequest) async -> ConnectionStartResult {
        generation &+= 1
        let attempt = generation

        state = .bootstrapping

        let bootstrapResult = await bootstrapper.bootstrap(
            server: request.server,
            credentials: request.credentials,
            context: request.bootstrapContext,
            attempt: BootstrapAttemptContext(runID: UUID(), queuePosition: 0),
            policy: request.bootstrapPolicy
        )

        guard attempt == generation, !Task.isCancelled else {
            return .cancelled
        }

        let bootstrap: ServerBootstrapResult
        switch bootstrapResult {
        case .success(let result):
            bootstrap = result
        case .failure(let failure):
            state = .failed(ManualConnectionFailure(reason: failure.safeDiagnostic ?? failure.kind.rawValue))
            return .failed(.bootstrap(failure.safeDiagnostic ?? failure.kind.rawValue))
        }

        guard attempt == generation, !Task.isCancelled else {
            return .cancelled
        }

        state = .startingTunnel
        let episodeID = ConnectionEpisodeID()
        activeEpisodeID = episodeID
        
        let config: TunnelStartupConfigurationV1
        do {
            config = try TunnelStartupConfigurationV1(
                episodeID: episodeID.rawValue,
                recoveryPolicy: request.tunnelRecoveryPolicy,
                serverHost: bootstrap.server.host,
                serverPort: bootstrap.server.port,
                accessToken: bootstrap.accessToken,
                dnsIPv4: bootstrap.dnsIPv4,
                dnsIPv6: bootstrap.dnsIPv6,
                sni: request.bootstrapContext.sni,
                md5Fingerprint: bootstrap.server.md5Fingerprint,
                censorshipStrategy: request.bootstrapContext.censorshipStrategy,
                logLevel: request.tunnelRuntimeOptions.logLevel,
                websocketIdleTimeoutSeconds: request.tunnelRuntimeOptions.websocketIdleTimeoutSeconds,
                customDnsIPv4: request.tunnelRuntimeOptions.customDnsIPv4,
                perAppMode: request.tunnelRuntimeOptions.perAppMode,
                allowedBundleIDs: request.tunnelRuntimeOptions.allowedBundleIDs
            )
        } catch {
            state = .failed(ManualConnectionFailure(reason: "Failed to create startup configuration: \(error)"))
            return .failed(.tunnelRefused("Invalid startup configuration"))
        }

        let tunnelResult = await tunnelController.start(episodeID: episodeID, configuration: config)

        guard attempt == generation, !Task.isCancelled else {
            if activeEpisodeID == episodeID { activeEpisodeID = nil }
            await tunnelController.stop(episodeID: episodeID, initiator: .appDisconnect)
            return .cancelled
        }

        switch tunnelResult {
        case .success:
            state = .connected(episodeID)
            return .started(episodeID)
        case .failure(let error):
            let msg: String
            switch error {
            case .refused(let s): msg = s
            }
            activeEpisodeID = nil
            state = .failed(ManualConnectionFailure(reason: msg))
            return .failed(.tunnelRefused(msg))
        }
    }

    public func disconnect(reason: DisconnectReason) async {
        generation &+= 1
        let episodeID = activeEpisodeID
        activeEpisodeID = nil
        state = .disconnecting
        if let episodeID {
            await tunnelController.stop(episodeID: episodeID, initiator: .appDisconnect)
        }
        state = .disconnected(.userInitiated)
    }

    public func handle(_ event: ConnectionEvent) async {
        switch event {
        case .tunnelDisconnected(let episodeID, let stopReason):
            guard case .connected(let current) = state, current == episodeID else { return }
            activeEpisodeID = nil
            let mappedReason: ManualDisconnectReason = {
                switch stopReason {
                case .userInitiated: return .userInitiated
                case .remoteClosed: return .remoteClosed
                case .networkLost: return .networkLost
                default: return .remoteClosed
                }
            }()
            state = .disconnected(mappedReason)

        case .tunnelConnected, .networkBecameSatisfied, .networkBecameUnsatisfied:
            break
        }
    }

    public func stateSnapshot() async -> ConnectionStateSnapshot {
        switch state {
        case .idle: return .idle
        case .bootstrapping: return .bootstrapping
        case .startingTunnel: return .startingTunnel
        case .connected(let id): return .connected(episodeID: id)
        case .disconnecting: return .disconnecting
        case .disconnected: return .disconnected
        case .failed(let f): return .failed(reason: f.reason)
        }
    }
}
