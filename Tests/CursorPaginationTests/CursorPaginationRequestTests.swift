//
//  CursorPaginationRequestTests.swift
//  CursorPagination
//
//  Created by Brian Strobach on 6/5/18.
//

import Foundation
import XCTest
import FluentExtensions
import Vapor
import Fluent
import CodableExtensions
import CursorPagination
import FluentTestModels

class CursorPaginationRequestTests: CursorPaginationTestCase {

    override func addRoutes(to router: Routes) throws {
        try super.addRoutes(to: router)
		router.get("models") { request -> Future<CursorPage<KitchenSink>> in
			return try KitchenSink.paginate(request: request,
											 sorts: .descending(\.$dateField), .ascending(\.$stringField))
		}

		router.get("dynamicModels") { request -> Future<CursorPage<KitchenSink>> in
			return try KitchenSink.paginate(request: request)
		}
	}
	
	func testPaginationRequest() throws{
		try seedModels(40)
        let existingModels = try KitchenSink.query(on: app.db).all().wait()
		let expectedTotalCount = existingModels.count
		let limit: Int = 5
		var cursor: String? = nil
		var models: [KitchenSink] = []
		repeat{
			var queryItems: [URLQueryItem] = []
			if let cursor = cursor{
				queryItems.append(URLQueryItem(name: "cursor", value: cursor))
			}
			queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))
            try app.test(.GET, "models", queryItems: queryItems, afterResponse: { response in
                let page: CursorPage<KitchenSink> = try response.content.decode(CursorPage<KitchenSink>.self)
                models.append(contentsOf: page.data)
                XCTAssert(page.data.count <= limit)
                cursor = page.nextPageCursor
            })
		} while cursor != nil
		
		XCTAssertEqual(models.count, expectedTotalCount)
	}

	func testDynamicPaginationRequest() throws{
		try seedModels(40)
        let existingModels = try KitchenSink.query(on: app.db).all().wait()
		let expectedTotalCount = existingModels.count
		let limit: Int = 5
		var cursor: String? = nil
		var models: [KitchenSink] = []
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

            try app.test(.GET, "dynamicModels", queryItems: queryItems, afterResponse: { response in
                let page: CursorPage<KitchenSink> = try response.content.decode(CursorPage<KitchenSink>.self)
                //            try debugPrint(page: page)
                models.append(contentsOf: page.data)
                XCTAssert(page.data.count <= limit)
                cursor = page.nextPageCursor
            })



        } while cursor != nil

		XCTAssertEqual(models.count, expectedTotalCount)
	}
}


import XCTVapor

public extension XCTApplicationTester {
    @discardableResult
    func test(_ method: NIOHTTP1.HTTPMethod,
                     _ path: String,
                     queryItems: [URLQueryItem],
                     headers: NIOHTTP1.HTTPHeaders = [:],
                     body: NIO.ByteBuffer? = nil,
                     file: StaticString = #file,
                     line: UInt = #line,
                     beforeRequest: (inout XCTVapor.XCTHTTPRequest) throws -> () = { _ in },
                     afterResponse: (XCTVapor.XCTHTTPResponse) throws -> () = { _ in }) throws -> XCTVapor.XCTApplicationTester {

        var urlComponents = URLComponents()
        urlComponents.path = path
        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url?.absoluteString else {
            throw Abort(.badRequest)
        }
        return try test(method, url, headers: headers, body: body, beforeRequest: beforeRequest, afterResponse: afterResponse)
    }
}
