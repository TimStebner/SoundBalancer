// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SoundBalancer",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(
            name: "SoundBalancer",
            targets: ["SoundBalancer"]
        )
    ],
    targets: [
        .executableTarget(
            name: "SoundBalancer",
            path: "Sources/SoundBalancer",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
