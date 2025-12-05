// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.
// DynamicAPI - Configuration-driven dynamic API client built on Moya
// License: GPLv3

import PackageDescription

let package = Package(
    name: "DynamicAPI",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "DynamicAPI",
            targets: ["DynamicAPI"]
        ),
        .library(
            name: "DynamicAPICombine",
            targets: ["DynamicAPICombine"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/Moya/Moya.git", from: "15.0.0")
    ],
    targets: [
        .target(
            name: "DynamicAPI",
            dependencies: [
                .product(name: "Moya", package: "Moya")
            ]
        ),
        .target(
            name: "DynamicAPICombine",
            dependencies: [
                "DynamicAPI",
                .product(name: "CombineMoya", package: "Moya")
            ]
        ),
        .executableTarget(
            name: "DynamicAPIExample",
            dependencies: ["DynamicAPI", "DynamicAPICombine"]
        ),
        .testTarget(
            name: "DynamicAPITests",
            dependencies: ["DynamicAPI"],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
