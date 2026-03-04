// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "FptnShared",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17)
    ],
    products: [
        .library(name: "FptnSharedCore", targets: ["FptnSharedCore"]),
        .library(name: "FptnSharedTunnel", targets: ["FptnSharedTunnel"]),
        .library(name: "FptnSharedTestSupport", targets: ["FptnSharedTestSupport"])
    ],
    targets: [
        .target(name: "FptnSharedCore"),
        .target(
            name: "FptnSharedTunnel",
            dependencies: ["FptnSharedCore"]
        ),
        .target(
            name: "FptnSharedTestSupport",
            dependencies: ["FptnSharedCore"]
        ),
        .testTarget(
            name: "FptnSharedCoreTests",
            dependencies: ["FptnSharedCore", "FptnSharedTestSupport"]
        )
    ]
)
