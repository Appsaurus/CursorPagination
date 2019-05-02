//
//  CursorPaginationTestCase.swift
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
import CursorPagination
import FluentTestApp
import VaporTestUtils
import FluentTestModels
extension ExampleModel: CursorPaginatable{}
extension ExampleChildModel: CursorPaginatable{}
extension ExampleSiblingModel: CursorPaginatable{}


class CursorPaginationTestCase: FluentAppTestCase {
	override open var autoSeed: Bool { return false }
	@discardableResult
	func seedModels(_ count: Int = 30) throws -> [ExampleModel] {
		return try ExampleModel.createBatchSync(size: count, factory: .random, on: request)		
	}

	func debugPrint<M: Model>(page: CursorPage<M>) throws{
		try page.toAnyDictionary().printPrettyJSONString()
	}

    open override func configure(databases: inout DatabasesConfig) throws{
        try super.configure(databases: &databases)
//        databases.enableLogging(on: .sqlite)
    }
}


