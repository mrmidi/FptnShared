import XCTest
@testable import FptnSharedCore
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
}
