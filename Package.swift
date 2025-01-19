// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CursorPagination",
    platforms: [
        .macOS(.v12),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(name: "CursorPagination", targets: ["CursorPagination"])
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/fluent.git", from:"4.0.0"),
        .package(url: "https://github.com/Appsaurus/FluentExtensions", from: "1.2.9"),
        .package(url: "https://github.com/Appsaurus/FluentSeeder", from: "1.2.0"),
        .package(url: "https://github.com/Appsaurus/CodableExtensions",  from: "1.1.0"),
        .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from:"4.0.0"),
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

