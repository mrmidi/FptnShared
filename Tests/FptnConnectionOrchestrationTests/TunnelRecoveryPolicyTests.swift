/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
import Testing
import FptnSharedCore
import FptnSharedTunnel
import FptnServerSelection
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

    @Test func missingPolicy_defaultsToNone() throws {
        let json = """
        {
            "schemaVersion": 1,
            "episodeID": "550E8400-E29B-41D4-A716-446655440000",
            "serverHost": "1.1.1.1",
            "serverPort": 443,
            "accessToken": "tok",
            "dnsIPv4": "10.0.0.1",
            "sni": "sni.test",
            "md5Fingerprint": "fp",
            "censorshipStrategy": "sni-reality-chrome147"
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(TunnelStartupConfiguration.self, from: json)
        #expect(decoded.recoveryPolicy == .none)
    }

    @Test func unknownSchemaVersion_failsDecoding() throws {
        let json = """
        {
            "schemaVersion": 99,
            "episodeID": "550E8400-E29B-41D4-A716-446655440000",
            "serverHost": "1.1.1.1",
            "serverPort": 443,
            "accessToken": "tok",
            "dnsIPv4": "10.0.0.1",
            "sni": "sni.test",
            "md5Fingerprint": "fp",
            "censorshipStrategy": "sni-reality-chrome147"
        }
        """.data(using: .utf8)!
        #expect(throws: TunnelStartupPayloadError.self) {
            try JSONDecoder().decode(TunnelStartupConfigurationV1.self, from: json)
        }
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
