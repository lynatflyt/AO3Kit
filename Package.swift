// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AO3Kit",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        .library(
            name: "AO3Kit",
            targets: ["AO3Kit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0")
    ],
    targets: [
        .target(
            name: "AO3Kit",
            dependencies: ["SwiftSoup"]
        ),
        .testTarget(
            name: "AO3KitTests",
            dependencies: ["AO3Kit"]
        ),
    ]
)
