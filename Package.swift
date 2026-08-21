// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "Kamidana",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(name: "Kamidana", targets: ["KamidanaApp"]),
    .executable(name: "kamidana-cli", targets: ["KamidanaCLI"])
  ],
  dependencies: [
    .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.0.0"),
    .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.6"),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0")
  ],
  targets: [
    .executableTarget(
      name: "KamidanaApp",
      dependencies: [
        .product(name: "SwiftTerm", package: "SwiftTerm"),
        .product(name: "Yams", package: "Yams")
      ],
      path: "Sources/KamidanaApp"
    ),
    .executableTarget(
      name: "KamidanaCLI",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser")
      ],
      path: "Sources/KamidanaCLI"
    ),
    .testTarget(
      name: "KamidanaTests",
      dependencies: ["KamidanaApp"],
      path: "Tests/KamidanaTests"
    ),
  ]
)
