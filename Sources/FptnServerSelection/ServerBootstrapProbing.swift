/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
#if !CLI_BUILD
import FptnSharedCore
#endif

/// Defines the contract for initiating a server bootstrap connection probe.
/// Any concrete networking transport (e.g. native C++ ApiClient client, simulation mock)
/// must conform to this protocol.
public protocol ServerBootstrapProbing: Sendable {
    /// Launches a bootstrap probe (connecting, TLS handshake, login, DNS retrieval)
    /// for a single candidate server.
    ///
    /// - Parameters:
    ///   - server: The candidate VPN server to probe.
    ///   - credentials: The credentials to log in with.
    ///   - context: The current network/SNI/strategy context parameters.
    ///   - timeout: The timeout interval for the probe operations.
    ///   - queuePosition: The index of the server in the queue (for diagnostic tracking).
    /// - Returns: A classified `ServerBootstrapAttempt` (success or failure).
    func probe(
        server: VPNServer,
        credentials: Credentials,
        context: ProbeContext,
        timeout: Duration,
        queuePosition: Int
    ) async -> ServerBootstrapAttempt
}
