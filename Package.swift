// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppleAIKit",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "NLUCore", targets: ["NLUCore"]),
        .library(name: "ToolRouter", targets: ["ToolRouter"]),
        .library(name: "ResponseEngine", targets: ["ResponseEngine"]),
        .library(name: "LLMEngine", targets: ["LLMEngine"]),
        .library(name: "LLMEngineApple", targets: ["LLMEngineApple"]),
        .library(name: "APIServer", targets: ["APIServer"]),
    ],
    dependencies: [],
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
        .target(
            name: "APIServer",
            dependencies: ["LLMEngine", "NLUCore", "ToolRouter", "ResponseEngine"],
            path: "Sources/APIServer"
        ),
    ]
)
