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
import CodableExtended
import CursorPagination


extension ExampleModel: CursorPaginatable{}
extension ExampleChildModel: CursorPaginatable{}
extension ExampleSiblingModel: CursorPaginatable{}


class CursorPaginationTestCase: FluentTestAppTestCase {
	@discardableResult
	func seedModels(_ count: Int = 30) throws -> [ExampleModel] {
		var models: [ExampleModel] = []
		switch count{
		case 1:
			models = [try ExampleModel.findOrCreateModel(id: 1)]
		case 2...Int.max:
			models = try ExampleModel.findOrCreateModels(ids: Array(1...count), on: request)
		default :
			break
		}
		return models
	}

	func debugPrint(models: [ExampleModel]) throws{
		try models.forEach { (item) in
			try item.toAnyDictionary().printPrettyJSONString()
		}
	}
	func debugPrint<M: Model>(page: CursorPage<M>) throws{
		try page.toAnyDictionary().printPrettyJSONString()
	}

	open override func configureApplication(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
		try super.configureApplication(&config, &env, &services)
		/// Create default content config
		var contentConfig = ContentConfig.default()

		/// Create custom JSON encoder
		let jsonEncoder: JSONEncoder = .defaultEncoder
		let jsonDecoder: JSONDecoder = .defaultDecoder

		/// Register JSON encoder and content config
		contentConfig.use(encoder: jsonEncoder, for: .json)
		contentConfig.use(decoder: jsonDecoder, for: .json)
		services.register(contentConfig)
	}
}


