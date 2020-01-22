// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EPUBKit",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "EPUBKit",
            targets: ["EPUBKit"]),
        .library(
            name: "EPUBKitDynamic",
            type: .dynamic,
            targets: ["EPUBKit"]),
        .library(
            name: "EPUBKitStatic",
            type: .static,
            targets: ["EPUBKit"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/sinoru/SNFoundation.swift.git", .revision("c3d299c227479b7d0c9e26599662d95066f9f5e5")),
        .package(url: "https://github.com/sinoru/Shinjuku.git", .revision("9870c26a60bbec70cc9900985672516c008b9a5a")),
        .package(url: "https://github.com/sinoru/CMinizip.swift.git", .upToNextMajor(from: "2.9.1")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "EPUBKit",
            dependencies: ["XMLKit", "SNFoundation", "Shinjuku", "CMinizip"]),
        .testTarget(
            name: "EPUBKitTests",
            dependencies: ["EPUBKit"]),
        .target(
            name: "XMLKit"),
        .testTarget(name: "XMLKitTests",
            dependencies: ["XMLKit"]),
    ]
)
