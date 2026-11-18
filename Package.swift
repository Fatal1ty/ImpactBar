// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ImpactBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ImpactBar", targets: ["ImpactBar"])
    ],
    targets: [
        .executableTarget(
            name: "ImpactBar"
        ),
        .testTarget(
            name: "ImpactBarTests",
            dependencies: ["ImpactBar"]
        )
    ],
    swiftLanguageModes: [.v5]
)
