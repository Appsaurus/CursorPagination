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
		("testPaginationRequest", testPaginationRequest),
		("testDynamicPaginationRequest", testDynamicPaginationRequest)
	]
	
	func testLinuxTestSuiteIncludesAllTests(){
		assertLinuxTestCoverage(tests: type(of: self).allTests)
	}
	
	override func configure(router: Router) throws {
		try super.configure(router: router)
		router.get("models") { request -> Future<CursorPage<ExampleModel>> in
			return try ExampleModel.paginate(request: request,
											 sorts: .descending(\.dateField), .ascending(\.stringField))
		}

		router.get("dynamicModels") { request -> Future<CursorPage<ExampleModel>> in
			return try ExampleModel.paginate(dynamicRequest: request)
		}
	}
	
	func testPaginationRequest() throws{
		try seedModels(40)
		let existingModels = try ExampleModel.query(on: request).all().wait()
		let expectedTotalCount = existingModels.count
		let limit: Int = 5
		var cursor: String? = nil
		var models: [ExampleModel] = []
		repeat{
			var queryItems: [URLQueryItem] = []
			if let cursor = cursor{
				queryItems.append(URLQueryItem(name: "cursor", value: cursor))
			}
			queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))
			let response = try executeRequest(method: .GET,
											  uri: "models",
											  queryItems: queryItems)
			let page: CursorPage<ExampleModel> = try response.content.decode(CursorPage<ExampleModel>.self).wait()
			models.append(contentsOf: page.data)
			XCTAssert(page.data.count <= limit)
			cursor = page.nextPageCursor
		} while cursor != nil
		
		XCTAssertEqual(models.count, expectedTotalCount)
	}

	func testDynamicPaginationRequest() throws{
		try seedModels(40)
		let existingModels = try ExampleModel.query(on: request).all().wait()
		let expectedTotalCount = existingModels.count
		let limit: Int = 5
		var cursor: String? = nil
		var models: [ExampleModel] = []
		repeat{
			var queryItems: [URLQueryItem] = []
			if let cursor = cursor{
				queryItems.append(URLQueryItem(name: "cursor", value: cursor))
			}
			queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))
			queryItems.append(URLQueryItem(name: "sort[]", value: "booleanField"))
			queryItems.append(URLQueryItem(name: "order[]", value: "descending"))
			queryItems.append(URLQueryItem(name: "sort[]", value: "stringField"))
			queryItems.append(URLQueryItem(name: "order[]", value: "ascending"))
			let response = try executeRequest(method: .GET,
											  uri: "dynamicModels",
											  queryItems: queryItems)
			let page: CursorPage<ExampleModel> = try response.content.decode(CursorPage<ExampleModel>.self).wait()
			models.append(contentsOf: page.data)
			XCTAssert(page.data.count <= limit)
			cursor = page.nextPageCursor
		} while cursor != nil

		XCTAssertEqual(models.count, expectedTotalCount)
	}
}
