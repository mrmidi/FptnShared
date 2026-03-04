import Foundation
import FptnSharedCore

public enum Fixtures {
    public static func sampleServer() -> VPNServer {
        VPNServer(name: "Auto", host: "vpn.example.com", port: 443, md5Fingerprint: "abc123")
    }

    public static func sampleToken() -> FPTNToken {
        FPTNToken(
            version: 1,
            serviceName: "fptn",
            username: "user",
            password: "pass",
            servers: [sampleServer()]
        )
    }
}
