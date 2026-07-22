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

}
