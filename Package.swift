// swift-tools-version:4.0

import PackageDescription

let package = Package(
	name: "CursorPagination",
	products: [
		.library(name: "CursorPagination", targets: ["CursorPagination"])
	],
	dependencies: [
		// 💧 A server-side Swift web framework.
		.package(url: "https://github.com/vapor/vapor.git", from: "3.0.0-rc.2"),
		// 🖋 Swift ORM framework (queries, models, and relations) for building NoSQL and SQL database integrations.
		.package(url: "https://github.com/vapor/fluent.git", from: "3.0.0-rc.2"),
		.package(url: "https://github.com/Appsaurus/FluentTestUtils", .upToNextMajor(from: "0.0.1"))
	],
	targets: [
		.target(name: "CursorPagination", dependencies: ["Vapor", "Fluent"]),
        .testTarget(name: "CursorPaginationTests", dependencies: ["CursorPagination", "FluentTestApp", "FluentTestUtils"])
	]
)
