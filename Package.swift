// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MosaicLab",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "MosaicLabKit",
            targets: ["MosaicLabKit"]
        ),
        .executable(
            name: "mosaiclab-cli",
            targets: ["mosaiclab-cli"]
        ),
        .executable(
            name: "MosaicLabApp",
            targets: ["MosaicLabApp"]
        )
    ],
    targets: [
        .target(
            name: "MosaicLabKit",
            dependencies: [],
            path: "Sources/MosaicLabKit"
        ),
        .executableTarget(
            name: "mosaiclab-cli",
            dependencies: ["MosaicLabKit"],
            path: "Sources/mosaiclab-cli"
        ),
        .executableTarget(
            name: "MosaicLabApp",
            dependencies: ["MosaicLabKit"],
            path: "Sources/MosaicLabApp"
        )
    ],
    swiftLanguageModes: [.v5]
)
