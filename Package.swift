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
        .executable(name: "fptn-selector", targets: ["FptnSelectionCLI"])
    ],
    targets: [
        .target(name: "FptnSharedCore"),
        .target(
            name: "FptnSharedTunnel",
            dependencies: ["FptnSharedCore"]
        ),
        .target(
            name: "FptnSharedTestSupport",
            dependencies: ["FptnSharedCore", "FptnServerSelection"]
        ),
        .target(
            name: "FptnServerSelection",
            dependencies: ["FptnSharedCore"]
        ),
        .executableTarget(
            name: "FptnSelectionCLI",
            dependencies: ["FptnSharedCore", "FptnServerSelection", "FptnSharedTestSupport"]
        ),
        .testTarget(
            name: "FptnSharedCoreTests",
            dependencies: ["FptnSharedCore", "FptnSharedTestSupport"]
        )
    ]
)
