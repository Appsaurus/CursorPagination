// swift-tools-version:5.0

import PackageDescription

let package = Package(
	name: "CursorPagination",
    platforms: [
        .macOS(.v10_12)
    ],
	products: [
		.library(name: "CursorPagination", targets: ["CursorPagination"])
	],
	dependencies: [
		.package(url: "https://github.com/vapor/vapor.git", from: "3.0.0"),
		.package(url: "https://github.com/vapor/fluent.git", from:"3.0.0"),
		.package(url: "https://github.com/Appsaurus/FluentTestApp", from: "0.1.0"),
		.package(url: "https://github.com/Appsaurus/CodableExtensions", from: "1.0.0"),
		.package(url: "https://github.com/Appsaurus/RuntimeExtensions", from: "0.1.0")

	],
	targets: [
		.target(name: "CursorPagination", dependencies: ["Vapor", "Fluent", "CodableExtensions", "RuntimeExtensions"]),
        .testTarget(name: "CursorPaginationTests", dependencies: ["CursorPagination", "FluentTestApp"]),
	]
)
