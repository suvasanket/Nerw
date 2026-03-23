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
        .library(name: "NerwExtensionKit", type: .static, targets: ["NerwExtensionKit"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
    ],
    targets: [
        // Extension Kit — standalone library for extension developers
        .target(
            name: "NerwExtensionKit",
            dependencies: [],
            path: "Sources/NerwExtensionKit"
        ),
        .target(
            name: "NerwCore",
            dependencies: ["NerwSearchBackend"],
            path: "Sources/NerwCore"
        ),
        .target(
            name: "NerwBuiltin",
            dependencies: ["NerwCore", "NerwSearchBackend"],
            path: "Sources/NerwBuiltin"
        ),
        .target(
            name: "NerwSearchBackend",
            dependencies: [],
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
            dependencies: ["NerwCore", "NerwBuiltin", "NerwSearchBackend", "NerwUtils"],
            path: "Sources/NerwUI"
        ),
        .executableTarget(
            name: "Nerw",
            dependencies: [
                "NerwCore", "NerwUI", "NerwBuiltin", "NerwUtils", "NerwExtensionKit",
            ],
            path: "Sources/Nerw"
        ),
    ]
)
