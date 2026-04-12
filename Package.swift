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
            name: "SagasuCore",
            dependencies: ["SagasuShared"],
            path: "Sources/Core"
        ),
        .target(
            name: "SagasuAutomationObjC",
            dependencies: [],
            path: "Sources/AutomationObjC",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("WebKit")
            ]
        ),
        .target(
            name: "SagasuHelperCore",
            dependencies: ["SagasuShared", "SagasuCore", "SagasuAutomationObjC"],
            path: "Sources/HelperCore"
        ),
        .executableTarget(
            name: "SagasuApp",
            dependencies: ["SagasuShared"],
            path: "Sources/App"
        ),
        .executableTarget(
            name: "SagasuHelper",
            dependencies: ["SagasuShared", "SagasuCore", "SagasuAutomationObjC", "SagasuHelperCore"],
            path: "Sources/Helper"
        ),
        .testTarget(
            name: "SagasuTests",
            dependencies: ["SagasuShared", "SagasuCore", "SagasuHelperCore"],
            path: "Tests/SagasuTests"
        )
    ]
)
