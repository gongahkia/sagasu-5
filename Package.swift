// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "sagasu",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "sagasu", targets: ["SagasuApp"]),
        .executable(name: "sagasu-helper", targets: ["SagasuHelper"])
    ],
    targets: [
        .target(
            name: "SagasuShared",
            path: "Sources/Shared"
        ),
        .target(
            name: "SagasuAutomationObjC",
            dependencies: [],
            path: "Sources/AutomationObjC",
            publicHeadersPath: "include"
        ),
        .executableTarget(
            name: "SagasuApp",
            dependencies: ["SagasuShared"],
            path: "Sources/App"
        ),
        .executableTarget(
            name: "SagasuHelper",
            dependencies: ["SagasuShared", "SagasuAutomationObjC"],
            path: "Sources/Helper"
        )
    ]
)
