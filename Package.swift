// swift-tools-version: 6.1.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FTNetworkTracer",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
        .tvOS(.v14),
        .watchOS(.v7)
    ],
    products: [
        .library(
            name: "FTNetworkTracer",
            targets: ["FTNetworkTracer"]
        )
    ],
    targets: [
        .target(
            name: "FTNetworkTracer",
            dependencies: []
        ),
        .testTarget(
            name: "FTNetworkTracerTests",
            dependencies: ["FTNetworkTracer"]
        )
    ]
)
