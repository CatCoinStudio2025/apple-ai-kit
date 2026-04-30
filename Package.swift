// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppleAIKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v15)
    ],
    products: [
        .library(name: "NLUCore", targets: ["NLUCore"]),
        .library(name: "ToolRouter", targets: ["ToolRouter"]),
        .library(name: "ResponseEngine", targets: ["ResponseEngine"]),
        .library(name: "LLMEngine", targets: ["LLMEngine"]),
        .library(name: "LLMEngineApple", targets: ["LLMEngineApple"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "NLUCore",
            path: "Sources/NLUCore"
        ),
        .target(
            name: "ToolRouter",
            dependencies: ["NLUCore"],
            path: "Sources/ToolRouter"
        ),
        .target(
            name: "ResponseEngine",
            dependencies: ["NLUCore", "ToolRouter"],
            path: "Sources/ResponseEngine"
        ),
        .target(
            name: "LLMEngine",
            dependencies: ["NLUCore"],
            path: "Sources/LLMEngine"
        ),
        .target(
            name: "LLMEngineApple",
            dependencies: ["LLMEngine"],
            path: "Sources/LLMEngineApple"
        ),
        .executableTarget(
            name: "AppleBaseLMApp",
            dependencies: ["NLUCore", "ToolRouter", "ResponseEngine", "LLMEngine", "LLMEngineApple"],
            path: "App/App"
        ),
    ]
)
