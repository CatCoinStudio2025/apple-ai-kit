// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NLUCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "NLUCore",
            targets: ["NLUCore"]
        )
    ],
    targets: [
        .target(
            name: "NLUCore",
            dependencies: [],
            path: "Sources"
        ),
        .testTarget(
            name: "NLUCoreTests",
            dependencies: ["NLUCore"],
            path: "Tests"
        )
    ]
)
