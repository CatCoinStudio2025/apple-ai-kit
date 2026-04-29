// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ResponseEngine",
    platforms: [.iOS(.v15), .macOS(.v15)],
    products: [
        .library(name: "ResponseEngine", targets: ["ResponseEngine"])
    ],
    dependencies: [
        .package(path: "../NLUCore"),
        .package(path: "../ToolRouter")
    ],
    targets: [
        .target(
            name: "ResponseEngine",
            dependencies: ["NLUCore", "ToolRouter"]
        )
    ]
)
