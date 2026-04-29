// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ResponseRenderer",
    platforms: [.iOS(.v15), .macOS(.v15)],
    products: [
        .library(name: "ResponseRenderer", targets: ["ResponseRenderer"])
    ],
    dependencies: [
        .package(path: "../NLUCore"),
        .package(path: "../ResponseEngine")
    ],
    targets: [
        .target(
            name: "ResponseRenderer",
            dependencies: ["NLUCore", "ResponseEngine"]
        )
    ]
)
