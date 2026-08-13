// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Kamidana",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Kamidana", targets: ["Kamidana"])
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "Kamidana",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
            path: "Sources/Kamidana"
        ),
        .testTarget(
            name: "KamidanaTests",
            dependencies: ["Kamidana"],
            path: "Tests/KamidanaTests"
        ),
    ]
)
