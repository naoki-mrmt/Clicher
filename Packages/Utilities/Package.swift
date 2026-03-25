// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Utilities",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Utilities", targets: ["Utilities"]),
    ],
    dependencies: [
        .package(path: "../SharedModels"),
    ],
    targets: [
        .target(
            name: "Utilities",
            dependencies: ["SharedModels"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "UtilitiesTests",
            dependencies: ["Utilities"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
