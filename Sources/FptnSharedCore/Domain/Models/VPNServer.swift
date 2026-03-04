public struct VPNServer: Codable, Sendable, Hashable, Identifiable {
    public var id: String { "\(host):\(port)" }

    public let name: String
    public let host: String
    public let port: Int
    public let md5Fingerprint: String

    public init(name: String, host: String, port: Int, md5Fingerprint: String) {
        self.name = name
        self.host = host
        self.port = port
        self.md5Fingerprint = md5Fingerprint
    }

    enum CodingKeys: String, CodingKey {
        case name
        case host
        case port
        case md5Fingerprint = "md5_fingerprint"
    }
}
