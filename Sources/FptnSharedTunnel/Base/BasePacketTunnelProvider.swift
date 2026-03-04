import Foundation
import FptnSharedCore

public protocol TunnelRuntime {
    func start() async throws
    func stop() async
}

public protocol TunnelRuntimeFactory {
    func makeRuntime(configuration: [String: Any]) throws -> TunnelRuntime
}

public final class BasePacketTunnelProvider {
    private let runtimeFactory: TunnelRuntimeFactory
    private var runtime: TunnelRuntime?

    public init(runtimeFactory: TunnelRuntimeFactory) {
        self.runtimeFactory = runtimeFactory
    }

    public func start(configuration: [String: Any]) async throws {
        let runtime = try runtimeFactory.makeRuntime(configuration: configuration)
        self.runtime = runtime
        try await runtime.start()
    }

    public func stop() async {
        await runtime?.stop()
        runtime = nil
    }
}
