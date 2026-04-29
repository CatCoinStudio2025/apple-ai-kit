// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ToolRouter",
    platforms: [.iOS(.v15), .macOS(.v15)],
    products: [
        .library(name: "ToolRouter", targets: ["ToolRouter"])
    ],
    dependencies: [
        .package(path: "../NLUCore")
    ],
    targets: [
        .target(
            name: "ToolRouter",
            dependencies: ["NLUCore"]
        )
    ]
)
