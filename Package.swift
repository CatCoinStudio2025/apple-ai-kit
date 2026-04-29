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
        .target(name: "NLUCore"),
        .target(name: "ToolRouter"),
        .target(name: "ResponseEngine"),
        .target(name: "LLMEngine"),
        .target(name: "LLMEngineApple"),
    ],
    targets: [
        .target(name: "NLUCore"),
        .target(name: "ToolRouter", dependencies: ["NLUCore"]),
        .target(name: "ResponseEngine", dependencies: ["NLUCore", "ToolRouter"]),
        .target(name: "LLMEngine", dependencies: ["NLUCore"]),
        .target(name: "LLMEngineApple", dependencies: ["LLMEngine"]),
    ]
)
