//
//  CursorPaginationTestCase.swift
//  CursorPagination
//
//  Created by Brian Strobach on 6/5/18.
//

import Foundation
import XCTest
import FluentTestModels
import Vapor
import Fluent
import CursorPagination
import XCTVaporExtensions
import FluentTestModelsSeeder

extension KitchenSink: CursorPaginatable{}
extension TestChildModel: CursorPaginatable{}
extension TestStudentModel: CursorPaginatable{}


class CursorPaginationTestCase: FluentTestModels.TestCase {

    override func configureTestModelDatabase(_ databases: Databases) {
        databases.use(.sqlite(.memory, connectionPoolTimeout: .minutes(2)), as: .sqlite)
    }
    @discardableResult
	func seedModels(_ count: Int = 30) async throws -> [KitchenSink] {
        let factory = ModelFactory.fluentFactory()
        factory.config.register(enumType: TestIntEnum.self)
        factory.config.register(enumType: TestStringEnum.self)
        factory.config.register(enumType: TestRawStringEnum.self)
        factory.config.register(enumType: TestRawIntEnum.self)
        return try await KitchenSink.createBatch(size: count, factory: factory, on: app.db)
	}

	func debugPrint<M: Model>(page: CursorPage<M>) throws{
		try page.toAnyDictionary().printPrettyJSONString()
	}


}


