// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LLMEngineApple",
    platforms: [
        .iOS(.v16),
        .macOS(.v15)
    ],
    products: [
        .library(name: "LLMEngineApple", targets: ["LLMEngineApple"])
    ],
    dependencies: [
        .package(path: "../LLMEngine")
    ],
    targets: [
        .target(
            name: "LLMEngineApple",
            dependencies: ["LLMEngine"]
        )
    ]
)
