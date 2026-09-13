// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AudioMixerClone",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AudioMixerClone", targets: ["AudioMixerClone"])
    ],
    targets: [
        .executableTarget(name: "AudioMixerClone")
    ]
)
