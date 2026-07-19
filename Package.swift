// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "FptnShared",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
        .tvOS(.v17)
    ],
    products: [
        .library(name: "FptnSharedCore", targets: ["FptnSharedCore"]),
        .library(name: "FptnSharedTunnel", targets: ["FptnSharedTunnel"]),
        .library(name: "FptnSharedTestSupport", targets: ["FptnSharedTestSupport"]),
        .library(name: "FptnServerSelection", targets: ["FptnServerSelection"]),
        .library(name: "FptnConnectionOrchestration", targets: ["FptnConnectionOrchestration"])
    ],
    targets: [
        .target(name: "FptnSharedCore"),
        .target(
            name: "FptnSharedTunnel",
            dependencies: ["FptnSharedCore"]
        ),
        .target(
            name: "FptnServerSelection",
            dependencies: ["FptnSharedCore"]
        ),
        .target(
            name: "FptnConnectionOrchestration",
            dependencies: ["FptnSharedCore", "FptnServerSelection"]
        ),
        .target(
            name: "FptnSharedTestSupport",
            dependencies: ["FptnSharedCore", "FptnServerSelection", "FptnConnectionOrchestration"]
        ),
        .testTarget(
            name: "FptnSharedCoreTests",
            dependencies: ["FptnSharedCore", "FptnSharedTestSupport"]
        ),
        .testTarget(
            name: "FptnConnectionOrchestrationTests",
            dependencies: ["FptnConnectionOrchestration", "FptnSharedTestSupport"]
        )
    ]
)
