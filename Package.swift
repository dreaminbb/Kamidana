// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Kamidana",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Kamidana", targets: ["Kamidana"]),
    ],
    targets: [
        .executableTarget(
            name: "Kamidana",
            path: "Sources/Kamidana"
        ),
        .testTarget(
            name: "KamidanaTests",
            dependencies: ["Kamidana"],
            path: "Tests/KamidanaTests"
        )
    ]
)
