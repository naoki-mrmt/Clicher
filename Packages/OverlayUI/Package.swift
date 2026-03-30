// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OverlayUI",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "OverlayUI", targets: ["OverlayUI"]),
    ],
    dependencies: [
        .package(path: "../SharedModels"),
        .package(path: "../Utilities"),
        .package(path: "../CaptureEngine"),
    ],
    targets: [
        .target(
            name: "OverlayUI",
            dependencies: ["SharedModels", "Utilities", "CaptureEngine"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "OverlayUITests",
            dependencies: ["OverlayUI"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
