// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CursorPagination",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(name: "CursorPagination", targets: ["CursorPagination"])
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", .upToNextMajor(from: "4.0.0")),
        .package(url: "https://github.com/vapor/fluent.git", .upToNextMajor(from: "4.0.0")),
        .package(url: "https://github.com/Appsaurus/FluentExtensions", .upToNextMajor(from: "1.1.0")),
        .package(url: "https://github.com/Appsaurus/FluentSeeder", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/Appsaurus/CodableExtensions",  .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", .upToNextMajor(from:"4.0.0")),
    ],
    targets: [
        .target(
            name: "CursorPagination",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "CodableExtensions", package: "CodableExtensions"),
                .product(name: "FluentExtensions", package: "FluentExtensions")
                
            ]),
        .testTarget(name: "CursorPaginationTests", dependencies: [
            .target(name: "CursorPagination"),
            .product(name: "FluentTestModelsSeeder", package: "FluentSeeder"),
            .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver")
        ])
    ]
)

