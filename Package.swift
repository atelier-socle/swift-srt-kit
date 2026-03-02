// swift-tools-version: 6.2
// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import PackageDescription

let package = Package(
    name: "swift-srt-kit",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "SRTKit", targets: ["SRTKit"]),
        .library(name: "SRTKitCommands", targets: ["SRTKitCommands"]),
        .executable(name: "srt-cli", targets: ["SRTKitCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.77.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.10.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.3"),
    ],
    targets: [
        .target(
            name: "SRTKit",
            dependencies: [
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "Crypto", package: "swift-crypto"),
            ]
        ),
        .target(
            name: "SRTKitCommands",
            dependencies: [
                "SRTKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .executableTarget(
            name: "SRTKitCLI",
            dependencies: ["SRTKitCommands"]
        ),
        .testTarget(
            name: "SRTKitTests",
            dependencies: ["SRTKit"]
        ),
        .testTarget(
            name: "SRTKitCommandsTests",
            dependencies: ["SRTKitCommands"]
        ),
    ]
)
