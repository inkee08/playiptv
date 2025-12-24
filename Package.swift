// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PlayIPTV",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "PlayIPTV", targets: ["PlayIPTV"])
    ],
    dependencies: [
        .package(url: "https://github.com/tylerjonesio/vlckit-spm", from: "3.6.0")
    ],
    targets: [
        .executableTarget(
            name: "PlayIPTV",
            dependencies: [
                .product(name: "VLCKitSPM", package: "vlckit-spm")
            ],
            path: "Sources/PlayIPTV"
        )
    ]
)
