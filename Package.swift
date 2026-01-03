// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Nerw",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "Nerw", targets: ["Nerw"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "NerwCore",
            dependencies: ["NerwSearchBackend"],
            path: "Sources/NerwCore"
        ),
        .target(
            name: "NerwBuiltin",
            dependencies: ["NerwCore"],
            path: "Sources/NerwBuiltin"
        ),
        .target(
            name: "NerwSearchBackend",
            dependencies: [],
            path: "Sources/NerwSearchBackend",
            exclude: ["Classes/Fuse_LICENSE"]
        ),
        .target(
            name: "NerwUI",
            dependencies: ["NerwCore", "NerwBuiltin", "NerwSearchBackend"],
            path: "Sources/NerwUI"
        ),
        .executableTarget(
            name: "Nerw",
            dependencies: ["NerwCore", "NerwUI", "NerwBuiltin"],
            path: "Sources/Nerw"
        ),
    ]
)
