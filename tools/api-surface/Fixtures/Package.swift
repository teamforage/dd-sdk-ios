// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "Fixtures",
    products: [
        .library(name: "Fixtures", targets: ["Fixtures"])
    ],
    dependencies: [],
    targets: [
        .target(name: "Fixtures", dependencies: [])
    ]
)
