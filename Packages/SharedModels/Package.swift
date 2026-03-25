// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SharedModels",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SharedModels", targets: ["SharedModels"]),
    ],
    targets: [
        .target(
            name: "SharedModels",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "SharedModelsTests",
            dependencies: ["SharedModels"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
