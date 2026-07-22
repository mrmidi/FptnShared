import Foundation

public enum TunnelProviderConfigKey {
    public static let server = "server"
    public static let port = "port"
    public static let accessToken = "accessToken"
    public static let dnsIPv4 = "dnsIPv4"
    public static let dnsIPv6 = "dnsIPv6"
    public static let sni = "sni"
    public static let md5Fingerprint = "md5Fingerprint"
    public static let logLevel = "logLevel"

    // Backward-compatible aliases for any legacy call sites.
    public static let serverHost = server
    public static let serverPort = port
}

public enum SharedLogLevel: String, Codable, Sendable {
    case warning
    case info
    case debug
}


public struct TunnelProviderPayload: Sendable, Equatable {
    public let server: String
    public let port: Int
    public let accessToken: String
    public let dnsIPv4: String
    public let dnsIPv6: String
    public let sni: String
    public let md5Fingerprint: String
    public let logLevel: SharedLogLevel

    public init(
        server: String,
        port: Int,
        accessToken: String,
        dnsIPv4: String,
        dnsIPv6: String,
        sni: String,
        md5Fingerprint: String,
        logLevel: SharedLogLevel
    ) {
        self.server = server
        self.port = port
        self.accessToken = accessToken
        self.dnsIPv4 = dnsIPv4
        self.dnsIPv6 = dnsIPv6
        self.sni = sni
        self.md5Fingerprint = md5Fingerprint
        self.logLevel = logLevel
    }

    public func asDictionary() -> [String: Any] {
        [
            TunnelProviderConfigKey.server: server,
            TunnelProviderConfigKey.port: port,
            TunnelProviderConfigKey.accessToken: accessToken,
            TunnelProviderConfigKey.dnsIPv4: dnsIPv4,
            TunnelProviderConfigKey.dnsIPv6: dnsIPv6,
            TunnelProviderConfigKey.sni: sni,
            TunnelProviderConfigKey.md5Fingerprint: md5Fingerprint,
            TunnelProviderConfigKey.logLevel: logLevel.rawValue
        ]
    }

    public init?(providerConfiguration: [String: Any]) {
        guard
            let server = providerConfiguration[TunnelProviderConfigKey.server] as? String,
            let port = providerConfiguration[TunnelProviderConfigKey.port] as? Int,
            let accessToken = providerConfiguration[TunnelProviderConfigKey.accessToken] as? String,
            let dnsIPv4 = providerConfiguration[TunnelProviderConfigKey.dnsIPv4] as? String,
            let sni = providerConfiguration[TunnelProviderConfigKey.sni] as? String,
            let md5Fingerprint = providerConfiguration[TunnelProviderConfigKey.md5Fingerprint] as? String
        else {
            return nil
        }

        let dnsIPv6 = (providerConfiguration[TunnelProviderConfigKey.dnsIPv6] as? String) ?? "fd00::1"
        let logLevelRaw = (providerConfiguration[TunnelProviderConfigKey.logLevel] as? String) ?? SharedLogLevel.warning.rawValue
        let logLevel = SharedLogLevel(rawValue: logLevelRaw) ?? .warning

        self.init(
            server: server,
            port: port,
            accessToken: accessToken,
            dnsIPv4: dnsIPv4,
            dnsIPv6: dnsIPv6,
            sni: sni,
            md5Fingerprint: md5Fingerprint,
            logLevel: logLevel
        )
    }
}
