import XCTest
@testable import FptnSharedCore
import FptnSharedTunnel
import FptnSharedTestSupport

final class FptnSharedCoreTests: XCTestCase {
    func testTokenRoundTripCodingKeys() throws {
        let token = Fixtures.sampleToken()
        let data = try JSONEncoder().encode(token)
        let decoded = try JSONDecoder().decode(FPTNToken.self, from: data)
        XCTAssertEqual(decoded, token)
    }

    func testServerIdentityUsesHostAndPort() {
        let server = Fixtures.sampleServer()
        XCTAssertEqual(server.id, "vpn.example.com:443")
    }

    func testTunnelControlMessageRoundTrip() throws {
        let message = TunnelControlMessage(action: .setLogLevel, logLevel: .debug)
        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(TunnelControlMessage.self, from: data)
        XCTAssertEqual(decoded, message)
    }

    func testTunnelProviderPayloadAsDictionaryAndParse() {
        let payload = TunnelProviderPayload(
            server: "vpn.example.com",
            port: 443,
            accessToken: "token",
            dnsIPv4: "1.1.1.1",
            dnsIPv6: "2606:4700:4700::1111",
            sni: "vpn.example.com",
            md5Fingerprint: "abc123",
            logLevel: .info
        )

        let dictionary = payload.asDictionary()
        let parsed = TunnelProviderPayload(providerConfiguration: dictionary)
        XCTAssertEqual(parsed, payload)
    }

    func testTunnelProviderPayloadUsesDefaults() {
        let providerConfiguration: [String: Any] = [
            TunnelProviderConfigKey.server: "vpn.example.com",
            TunnelProviderConfigKey.port: 443,
            TunnelProviderConfigKey.accessToken: "token",
            TunnelProviderConfigKey.dnsIPv4: "1.1.1.1",
            TunnelProviderConfigKey.sni: "vpn.example.com",
            TunnelProviderConfigKey.md5Fingerprint: "abc123"
        ]

        let parsed = TunnelProviderPayload(providerConfiguration: providerConfiguration)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.dnsIPv6, "fd00::1")
        XCTAssertEqual(parsed?.logLevel, .warning)
    }
}
