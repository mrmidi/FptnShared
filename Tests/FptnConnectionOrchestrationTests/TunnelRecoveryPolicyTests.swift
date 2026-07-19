/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
import Testing
import FptnSharedCore
import FptnConnectionOrchestration

struct TunnelRecoveryPolicyTests {

    @Test func none_encodesAndDecodes() throws {
        let policy: TunnelRecoveryPolicy = .none
        let encoded = try JSONEncoder().encode(policy)
        let decoded = try JSONDecoder().decode(TunnelRecoveryPolicy.self, from: encoded)
        #expect(decoded == policy)
    }

    @Test func automatic_encodesAndDecodes() throws {
        let policy: TunnelRecoveryPolicy = .automatic(AutoTunnelRecoveryPolicy(sameServerAttempts: 3, reconnectDelaySeconds: 5))
        let encoded = try JSONEncoder().encode(policy)
        let decoded = try JSONDecoder().decode(TunnelRecoveryPolicy.self, from: encoded)
        #expect(decoded == policy)
    }

    @Test func missingPolicy_decodesSafelyAsNone() throws {
        let json = "{}".data(using: .utf8)!
        let decoded = try? JSONDecoder().decode(TunnelRecoveryPolicy.self, from: json)
        #expect(decoded == nil)
    }
}

struct ConnectionEpisodeIDTests {

    @Test func uniquePerInitialization() {
        let id1 = ConnectionEpisodeID()
        let id2 = ConnectionEpisodeID()
        #expect(id1 != id2)
    }

    @Test func encodableRoundTrip() throws {
        let id = ConnectionEpisodeID()
        let encoded = try JSONEncoder().encode(id)
        let decoded = try JSONDecoder().decode(ConnectionEpisodeID.self, from: encoded)
        #expect(decoded == id)
    }
}
