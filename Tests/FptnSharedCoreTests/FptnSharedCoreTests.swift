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

    func testTunnelTrafficSnapshotRoundTrip() throws {
        let snapshot = TunnelTrafficSnapshotV1(
            sessionUploadBytes: 12_345,
            sessionDownloadBytes: 67_890,
            peakUploadBytesPerSecond: 5_000,
            peakDownloadBytesPerSecond: 60_000,
            peakBandwidthNominalWindowSeconds: 15,
            sessionStartMonotonicTime: 1_000,
            sampleMonotonicTime: 2_000
        )
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(TunnelTrafficSnapshotV1.self, from: data)
        XCTAssertEqual(decoded, snapshot)
    }

    func testTunnelStatusSnapshotRoundTrip() throws {
        let status = TunnelStatusSnapshotV1(
            traffic: TunnelTrafficSnapshotV1(
                sessionUploadBytes: 12_345,
                sessionDownloadBytes: 67_890,
                peakUploadBytesPerSecond: 5_000,
                peakDownloadBytesPerSecond: 60_000,
                peakBandwidthNominalWindowSeconds: 1,
                sessionStartMonotonicTime: 1_000,
                sampleMonotonicTime: 2_000
            ),
            memoryFootprintBytes: 45_100_000,
            memoryResidentBytes: 48_000_000,
            memoryFootprintPeakBytes: 45_100_000,
            outboundQueuedBytes: 0,
            outboundQueuedBytesPeak: 10_240,
            queueFullCount: 0,
            livePacketLeases: 482,
            peakPacketLeases: 482,
            nativeActiveOperations: 3,
            sessionToken: 0x155B663ACBF64B3B,
            websocketGeneration: 1,
            reconnectAttempt: 0
        )
        let data = try JSONEncoder().encode(status)
        let decoded = try JSONDecoder().decode(TunnelStatusSnapshotV1.self, from: data)
        XCTAssertEqual(decoded, status)
    }

}
