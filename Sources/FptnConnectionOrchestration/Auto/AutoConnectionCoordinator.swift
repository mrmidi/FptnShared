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

    public init(
        selector: any AutoSelecting,
        tunnelController: any TunnelControlling,
        clock: any Clock = SystemClock()
    ) {
        self.selector = selector
        self.tunnelController = tunnelController
        self.clock = clock
    }

    public func connect() async -> ConnectionStartResult {
        state = .selecting

        let request = SelectionRequest(
            servers: [],
            credentials: Credentials(username: "", password: ""),
            context: BootstrapContext(
                networkClass: .wifi,
                sni: "",
                censorshipStrategy: CensorshipStrategy(storedValue: ""),
                ipv6Available: false,
                tokenConfigurationID: ""
            ),
            policy: .production
        )

        let outcome = await selector.select(request)

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
                sni: "",
                md5Fingerprint: bootstrap.server.md5Fingerprint,
                censorshipStrategy: ""
            )
            let tunnelResult = await tunnelController.start(episodeID: episodeID, configuration: config)
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
        await tunnelController.stop()
        state = .idle
    }

    public func handle(_ event: ConnectionEvent) async {
        switch event {
        case .tunnelDisconnected(let episodeID, let stopReason):
            guard case .connected(let current) = state, current == episodeID else { return }
            switch stopReason {
            case .networkLost:
                state = .waitingForNetwork
            default:
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
        case .selecting, .selectingReplacement, .retryingCurrentServer, .handingOff, .stabilizing: return .bootstrapping
        case .startingTunnel: return .startingTunnel
        case .connected(let id): return .connected(episodeID: id)
        case .waitingForNetwork: return .failed(reason: "waiting for network")
        case .exhausted: return .failed(reason: "all servers exhausted")
        case .failed(let f): return .failed(reason: "\(f)")
        }
    }
}
