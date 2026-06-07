// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "BarMaster",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "BarMasterCore", targets: ["BarMasterCore"]),
        .executable(name: "BarMaster", targets: ["BarMaster"]),
    ],
    dependencies: [
        .package(path: "../iUX-MacOS"),
    ],
    targets: [
        .target(
            name: "BarMasterCore",
            dependencies: ["iUX-MacOS"],
            path: "Sources/BarMasterCore"
        ),
        .executableTarget(
            name: "BarMaster",
            dependencies: ["BarMasterCore"],
            path: "Sources/BarMaster"
        ),
        .testTarget(
            name: "BarMasterCoreTests",
            dependencies: ["BarMasterCore"],
            path: "Tests/BarMasterCoreTests"
        ),
    ]
)
