/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
import FptnSharedCore
import FptnServerSelection

public actor ManualConnectionCoordinator: ConnectionCoordinating {
    private let server: VPNServer
    private let bootstrapper: any ServerBootstrapping
    private let tunnelController: any TunnelControlling
    private let clock: any Clock

    private var state: ManualConnectionState = .idle
    private var generation: UInt64 = 0

    public init(
        server: VPNServer,
        bootstrapper: any ServerBootstrapping,
        tunnelController: any TunnelControlling,
        clock: any Clock = SystemClock()
    ) {
        self.server = server
        self.bootstrapper = bootstrapper
        self.tunnelController = tunnelController
        self.clock = clock
    }

    public func connect() async -> ConnectionStartResult {
        generation &+= 1
        let attempt = generation

        state = .bootstrapping

        let bootstrapResult = await bootstrapper.bootstrap(
            server: server,
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

        guard attempt == generation, !Task.isCancelled else {
            state = .failed(ManualConnectionFailure(reason: "cancelled"))
            return .cancelled
        }

        let bootstrap: ServerBootstrapResult
        switch bootstrapResult {
        case .success(let result):
            bootstrap = result
        case .failure(let failure):
            state = .failed(ManualConnectionFailure(reason: failure.message))
            return .failed(.bootstrap(failure.message))
        }

        guard attempt == generation else {
            state = .failed(ManualConnectionFailure(reason: "cancelled"))
            return .cancelled
        }

        state = .startingTunnel
        let episodeID = ConnectionEpisodeID()
        let config = TunnelStartupConfiguration(
            episodeID: episodeID.rawValue,
            recoveryPolicy: .none,
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

        guard attempt == generation else {
            await tunnelController.stop()
            state = .failed(ManualConnectionFailure(reason: "cancelled"))
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
            state = .failed(ManualConnectionFailure(reason: msg))
            return .failed(.tunnelRefused(msg))
        }
    }

    public func disconnect(reason: DisconnectReason) async {
        generation &+= 1
        state = .disconnecting
        await tunnelController.stop()
        state = .disconnected(.userInitiated)
    }

    public func handle(_ event: ConnectionEvent) async {
        switch event {
        case .tunnelDisconnected(let episodeID, let stopReason):
            guard case .connected(let current) = state, current == episodeID else { return }
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
