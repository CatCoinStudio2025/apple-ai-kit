// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LLMEngine",
    platforms: [
        .iOS(.v16),
        .macOS(.v15)
    ],
    products: [
        .library(name: "LLMEngine", targets: ["LLMEngine"])
    ],
    dependencies: [
        .package(path: "../NLUCore")
    ],
    targets: [
        .target(
            name: "LLMEngine",
            dependencies: ["NLUCore"]
        )
    ]
)
