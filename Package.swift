// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VitaminDTrackerCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "VitaminDTrackerCore",
            targets: ["VitaminDTrackerCore"]
        )
    ],
    targets: [
        .target(
            name: "VitaminDTrackerCore",
            path: "Sources/VitaminDTrackerCore"
        ),
        .testTarget(
            name: "VitaminDTrackerCoreTests",
            dependencies: ["VitaminDTrackerCore"],
            path: "Tests/VitaminDTrackerCoreTests"
        )
    ]
)
