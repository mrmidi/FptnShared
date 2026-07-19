/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
import FptnSharedCore
import FptnServerSelection

public actor AutoConnectionCoordinator: ConnectionCoordinating {
    private let selector: any AutoSelecting
    private let tunnelController: any TunnelControlling
    private let clock: any Clock

    private var state: AutoConnectionState = .idle
    private var generation: UInt64 = 0

    public init(
        selector: any AutoSelecting,
        tunnelController: any TunnelControlling,
        clock: any Clock = SystemClock()
    ) {
        self.selector = selector
        self.tunnelController = tunnelController
        self.clock = clock
    }

    public func connect(_ request: ConnectionRequest) async -> ConnectionStartResult {
        guard case .auto(let autoRequest) = request else {
            return .failed(.bootstrap("Expected auto connection request"))
        }

        generation &+= 1
        let attempt = generation

        state = .selecting

        let selectionRequest = SelectionRequest(
            servers: autoRequest.servers,
            credentials: autoRequest.credentials,
            context: autoRequest.bootstrapContext,
            policy: autoRequest.bootstrapPolicy
        )

        let outcome = await selector.select(selectionRequest)

        guard attempt == generation, !Task.isCancelled else {
            return .cancelled
        }

        switch outcome.result {
        case .success(let bootstrap):
            state = .startingTunnel
            let episodeID = ConnectionEpisodeID()
            let config = TunnelStartupConfiguration(
                episodeID: episodeID.rawValue,
                recoveryPolicy: .automatic(AutoTunnelRecoveryPolicy(sameServerAttempts: 2, reconnectDelaySeconds: 2)),
                serverHost: bootstrap.server.host,
                serverPort: bootstrap.server.port,
                accessToken: bootstrap.accessToken,
                dnsIPv4: bootstrap.dnsIPv4,
                dnsIPv6: bootstrap.dnsIPv6,
                sni: autoRequest.bootstrapContext.sni,
                md5Fingerprint: bootstrap.server.md5Fingerprint,
                censorshipStrategy: autoRequest.bootstrapContext.censorshipStrategy.rawValue
            )
            let tunnelResult = await tunnelController.start(episodeID: episodeID, configuration: config)

            guard attempt == generation, !Task.isCancelled else {
                await tunnelController.stop(episodeID: episodeID)
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
                state = .failed(.internalError(msg))
                return .failed(.tunnelRefused(msg))
            }

        case .allCandidatesFailed:
            state = .exhausted
            return .failed(.noServers)

        case .authenticationRejected:
            state = .failed(.authenticationRejected)
            return .failed(.bootstrap("authentication rejected"))

        case .networkUnavailable:
            state = .failed(.networkUnavailable)
            return .failed(.noNetwork)

        case .rateLimited:
            state = .failed(.allExhausted)
            return .failed(.bootstrap("rate limited"))

        case .cancelled:
            state = .idle
            return .cancelled
        }
    }

    public func disconnect(reason: DisconnectReason) async {
        generation &+= 1
        await tunnelController.stop(episodeID: ConnectionEpisodeID())
        state = .idle
    }

    public func handle(_ event: ConnectionEvent) async {
        switch event {
        case .tunnelDisconnected(let episodeID, let stopReason):
            guard case .connected(let current) = state, current == episodeID else { return }
            switch stopReason {
            case .userInitiated:
                state = .idle
            case .authenticationFailed:
                state = .failed(.authenticationRejected)
            case .networkLost:
                state = .waitingForNetwork
            case .remoteClosed, .transportError:
                state = .selectingReplacement
            case .unknown:
                state = .selectingReplacement
            }

        case .networkBecameSatisfied:
            if case .waitingForNetwork = state {
                state = .selectingReplacement
            }

        case .tunnelConnected, .networkBecameUnsatisfied:
            break
        }
    }

    public func stateSnapshot() async -> ConnectionStateSnapshot {
        switch state {
        case .idle: return .idle
        case .selecting: return .selecting
        case .startingTunnel: return .startingTunnel
        case .connected(let id): return .connected(episodeID: id)
        case .waitingForNetwork: return .waitingForNetwork
        case .retryingCurrentServer: return .retrying
        case .selectingReplacement: return .selectingReplacement
        case .handingOff: return .stabilizing
        case .stabilizing: return .stabilizing
        case .exhausted: return .exhausted
        case .failed(let f): return .failed(reason: "\(f)")
        }
    }
}
