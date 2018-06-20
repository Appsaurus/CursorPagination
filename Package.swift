// swift-tools-version:4.0

import PackageDescription

let package = Package(
	name: "CursorPagination",
	products: [
		.library(name: "CursorPagination", targets: ["CursorPagination"])
	],
	dependencies: [
		// 💧 A server-side Swift web framework.
		.package(url: "https://github.com/vapor/vapor.git", from: "3.0.0"),
		// 🖋 Swift ORM framework (queries, models, and relations) for building NoSQL and SQL database integrations.
		.package(url: "https://github.com/vapor/fluent.git", .exact("3.0.0-rc.4")),
		.package(url: "https://github.com/Appsaurus/FluentTestUtils", .exact("1.0.0-rc.5"))
	],
	targets: [
		.target(name: "CursorPagination", dependencies: ["Vapor", "Fluent"]),
        .testTarget(name: "CursorPaginationTests", dependencies: ["CursorPagination", "FluentTestApp", "FluentTestUtils"])
	]
)
