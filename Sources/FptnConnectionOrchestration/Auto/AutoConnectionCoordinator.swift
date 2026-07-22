/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
import FptnSharedCore
import FptnSharedTunnel
import FptnServerSelection

public actor AutoConnectionCoordinator: AutoConnectionCoordinating {
    private let selector: any AutoSelecting
    private let tunnelController: any TunnelControlling
    private let clock: any Clock

    private var state: AutoConnectionState = .idle
    private var generation: UInt64 = 0
    private var activeEpisodeID: ConnectionEpisodeID?
    private var lastRequest: AutoConnectionRequest?
    private var remainingReplacementAttempts: Int = 0
    private var replacementTask: Task<Void, Never>?

    public init(
        selector: any AutoSelecting,
        tunnelController: any TunnelControlling,
        clock: any Clock = SystemClock()
    ) {
        self.selector = selector
        self.tunnelController = tunnelController
        self.clock = clock
    }

    public func connect(_ request: AutoConnectionRequest) async -> ConnectionStartResult {
        generation &+= 1
        lastRequest = request
        remainingReplacementAttempts = request.reselectionPolicy.maxReplacementAttempts
        return await executeSelectionAndConnect(request, attempt: generation)
    }

    private func executeSelectionAndConnect(_ request: AutoConnectionRequest, attempt: UInt64) async -> ConnectionStartResult {
        state = .selecting

        let selectionRequest = SelectionRequest(
            servers: request.servers,
            credentials: request.credentials,
            context: request.bootstrapContext,
            bootstrapPolicy: request.bootstrapPolicy,
            selectionPolicy: request.selectionPolicy
        )

        let run = await selector.select(selectionRequest)

        guard attempt == generation, !Task.isCancelled else {
            return .cancelled
        }

        switch run.result {
        case .success(let bootstrap):
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
                state = .failed(.internalError("Invalid startup configuration"))
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
        replacementTask?.cancel()
        replacementTask = nil
        let episodeID = activeEpisodeID
        activeEpisodeID = nil
        lastRequest = nil
        remainingReplacementAttempts = 0
        state = .disconnecting
        if let episodeID {
            await tunnelController.stop(episodeID: episodeID, initiator: .appDisconnect)
        }
        state = .idle
    }

    public func handle(_ event: ConnectionEvent) async {
        switch event {
        case .tunnelDisconnected(let episodeID, let stopReason):
            guard case .connected(let current) = state, current == episodeID else { return }
            activeEpisodeID = nil
            switch stopReason {
            case .userInitiated:
                state = .idle
                lastRequest = nil

            case .authenticationFailed:
                state = .failed(.authenticationRejected)
                lastRequest = nil

            case .networkLost:
                state = .waitingForNetwork

            case .remoteClosed, .transportError, .unknown:
                await triggerReplacementSelection(consumesBudget: true)
            }

        case .networkBecameSatisfied:
            if case .waitingForNetwork = state {
                await triggerReplacementSelection(consumesBudget: false)
            }

        case .networkBecameUnsatisfied:
            if case .connected = state {
                // Network lost while connected: transition to waitingForNetwork
                state = .waitingForNetwork
            }

        case .tunnelConnected:
            break
        }
    }

    private func triggerReplacementSelection(consumesBudget: Bool) async {
        guard let request = lastRequest else {
            state = .exhausted
            return
        }
        if consumesBudget {
            guard remainingReplacementAttempts > 0 else {
                state = .exhausted
                return
            }
            remainingReplacementAttempts -= 1
        }
        replacementTask?.cancel()
        state = .selectingReplacement
        let currentAttempt = generation
        replacementTask = Task { [weak self, clock] in
            guard let self else { return }
            do {
                try await clock.sleep(for: .seconds(request.reselectionPolicy.delaySeconds))
            } catch {
                return
            }
            _ = await self.executeSelectionAndConnect(request, attempt: currentAttempt)
        }
    }

    public func stateSnapshot() async -> ConnectionStateSnapshot {
        switch state {
        case .idle: return .idle
        case .selecting: return .selecting
        case .startingTunnel: return .startingTunnel
        case .connected(let id): return .connected(episodeID: id)
        case .disconnecting: return .disconnecting
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
