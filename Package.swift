// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AO3Kit",
    platforms: [
        .macOS(.v13),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v9)
    ],
    products: [
        .library(
            name: "AO3Kit",
            targets: ["AO3Kit"]
        ),
        .library(
            name: "AO3KitUI",
            targets: ["AO3KitUI"]
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
        .target(
            name: "AO3KitUI",
            dependencies: ["AO3Kit", "SwiftSoup"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "AO3KitTests",
            dependencies: ["AO3Kit"]
        ),
    ]
)
