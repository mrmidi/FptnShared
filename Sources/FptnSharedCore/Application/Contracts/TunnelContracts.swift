import Foundation

public enum TunnelProviderConfigKey {
    public static let serverHost = "serverHost"
    public static let serverPort = "serverPort"
    public static let accessToken = "accessToken"
    public static let dnsIPv4 = "dnsIPv4"
    public static let dnsIPv6 = "dnsIPv6"
    public static let sni = "sni"
    public static let md5Fingerprint = "md5Fingerprint"
    public static let logLevel = "logLevel"
}

public enum SharedLogLevel: String, Codable, Sendable {
    case warning
    case info
    case debug
}

public struct TunnelControlMessage: Codable, Sendable, Equatable {
    public let action: String
    public let logLevel: SharedLogLevel?

    public init(action: String, logLevel: SharedLogLevel? = nil) {
        self.action = action
        self.logLevel = logLevel
    }
}
