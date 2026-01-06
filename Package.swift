// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "sagasu",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "sagasu", targets: ["sagasu"])
    ],
    targets: [
        .executableTarget(
            name: "sagasu",
            path: "Sources"
        )
    ]
)
