// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "VocabPocket",
    defaultLocalization: "zh-Hans",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "VocabPocket", targets: ["VocabPocket"])
    ],
    targets: [
        .executableTarget(
            name: "VocabPocket",
            path: "Sources/VocabPocket",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "VocabPocketTests",
            dependencies: ["VocabPocket"],
            path: "Tests/VocabPocketTests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
    ]
)
