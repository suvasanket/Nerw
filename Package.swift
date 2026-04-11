// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Nerw",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "Nerw", targets: ["Nerw"]),
        .executable(name: "nerw-cli", targets: ["NerwCLI"]),
        .library(name: "NerwExtensionKit", type: .static, targets: ["NerwExtensionKit"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
    ],
    targets: [
        // CLI Tool
        .executableTarget(
            name: "NerwCLI",
            dependencies: [
                "NerwSearchBackend"
            ],
            path: "Sources/NerwCLI"
        ),
        // Extension Kit — standalone library for extension developers
        .target(
            name: "NerwExtensionKit",
            dependencies: [],
            path: "Sources/NerwExtensionKit"
        ),
        .target(
            name: "NerwAction",
            dependencies: ["NerwSearchBackend", "NerwUtils"],
            path: "Sources/NerwAction"
        ),
        .target(
            name: "NerwCore",
            dependencies: ["NerwSearchBackend", "NerwUtils", "NerwAction"],
            path: "Sources/NerwCore"
        ),
        .target(
            name: "NerwBuiltin",
            dependencies: ["NerwCore", "NerwSearchBackend", "NerwUtils", "NerwAction"],
            path: "Sources/NerwBuiltin"
        ),
        .target(
            name: "NerwSearchBackend",
            dependencies: ["NerwUtils"],
            path: "Sources/NerwSearchBackend",
            exclude: ["Classes/Fuse_LICENSE"]
        ),
        .target(
            name: "NerwUtils",
            dependencies: [],
            path: "Sources/NerwUtils"
        ),
        .target(
            name: "NerwUI",
            dependencies: [
                "NerwCore", "NerwBuiltin", "NerwSearchBackend", "NerwUtils", "NerwAction",
            ],
            path: "Sources/NerwUI"
        ),
        .executableTarget(
            name: "Nerw",
            dependencies: [
                "NerwCore", "NerwUI", "NerwBuiltin", "NerwUtils", "NerwExtensionKit", "NerwAction",
            ],
            path: "Sources/Nerw"
        ),
        .executableTarget(
            name: "SearchServiceTests",
            dependencies: [
                "NerwCore", "NerwSearchBackend", "NerwBuiltin", "NerwUtils", "NerwUI", "NerwAction",
            ],
            path: "Tests/SearchServiceTests"
        ),
    ]
)
