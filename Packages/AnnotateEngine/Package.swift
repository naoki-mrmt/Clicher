// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AnnotateEngine",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AnnotateEngine", targets: ["AnnotateEngine"]),
    ],
    dependencies: [
        .package(path: "../SharedModels"),
        .package(path: "../Utilities"),
    ],
    targets: [
        .target(
            name: "AnnotateEngine",
            dependencies: ["SharedModels", "Utilities"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "AnnotateEngineTests",
            dependencies: ["AnnotateEngine"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
