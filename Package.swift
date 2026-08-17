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
    .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.0.0"),
    .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.6")
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .executableTarget(
      name: "Kamidana",
      dependencies: [
        .product(name: "SwiftTerm", package: "SwiftTerm"),
        .product(name: "Yams", package: "Yams")
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
