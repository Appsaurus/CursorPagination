//
//  CursorPaginationRequestTests.swift
//  CursorPagination
//
//  Created by Brian Strobach on 6/5/18.
//

import Foundation
import XCTest
import FluentTestApp
import Vapor
import Fluent
import HTTP
import CodableExtended
import CursorPagination

class CursorPaginationRequestTests: CursorPaginationTestCase {

	//MARK: Linux Testing
	static var allTests = [
		("testLinuxTestSuiteIncludesAllTests", testLinuxTestSuiteIncludesAllTests),
		("testPaginationRequest", testPaginationRequest)
	]

	func testLinuxTestSuiteIncludesAllTests(){
		assertLinuxTestCoverage(tests: type(of: self).allTests)
	}

	override func setupOnce() throws {
		try super.setupOnce()
		CursorPaginationRequestTests.persistApplicationBetweenTests = true
		try seedModels(20)
	}

	override func configure(router: Router) throws {
		try super.configure(router: router)
		router.get("models") { request -> Future<CursorPage<ExampleModel>> in
			return try ExampleModel.paginate(request: request,
											 sorts: .descending(\.dateField), .ascending(\.stringField))
		}
	}

	func testPaginationRequest() throws{
//		let existingModels = try ExampleModel.query(on: request).all().wait()
//		let expectedTotalCount = existingModels.count
//		var cursor: String? = nil
//		var models: [ExampleModel] = []
//		repeat{
//			var queryItems: [URLQueryItem] = []
//			if let cursor = cursor{
//				queryItems.append(URLQueryItem(name: "cursor", value: cursor))
//			}
//			let response = try executeRequest(method: .GET,
//											  uri: "models",
//											  queryItems: queryItems)
//			let page: CursorPage<ExampleModel> = try response.content.decode(CursorPage<ExampleModel>.self).wait()
//			models.append(contentsOf: page.data)
//			cursor = page.nextPageCursor
//		} while cursor != nil
//
//		XCTAssertEqual(models.count, expectedTotalCount)
	}
}
