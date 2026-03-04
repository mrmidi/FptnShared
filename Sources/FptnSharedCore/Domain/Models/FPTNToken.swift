import Foundation

public struct FPTNToken: Codable, Sendable, Equatable {
    public let version: Int
    public let serviceName: String
    public let username: String
    public let password: String
    public let servers: [VPNServer]

    public init(version: Int, serviceName: String, username: String, password: String, servers: [VPNServer]) {
        self.version = version
        self.serviceName = serviceName
        self.username = username
        self.password = password
        self.servers = servers
    }

    enum CodingKeys: String, CodingKey {
        case version
        case serviceName = "service_name"
        case username
        case password
        case servers
    }
}
