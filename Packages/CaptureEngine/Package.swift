// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CaptureEngine",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CaptureEngine", targets: ["CaptureEngine"]),
    ],
    dependencies: [
        .package(path: "../SharedModels"),
        .package(path: "../Utilities"),
    ],
    targets: [
        .target(
            name: "CaptureEngine",
            dependencies: ["SharedModels", "Utilities"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "CaptureEngineTests",
            dependencies: ["CaptureEngine"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
