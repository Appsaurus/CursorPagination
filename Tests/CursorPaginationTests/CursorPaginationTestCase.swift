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


class PaginationTestCase: FluentTestAppTestCase {
	@discardableResult
	func seedModels(_ count: Int = 30) throws -> [ExampleModel] {
		var models = try ExampleModel.query(on: request).all().wait()
		let total: Int = models.count
		guard total != count else{
			return models //Seed is alraedy setup for this seed size.
		}
		//Otherwise we need to reseed
		try! ExampleModel.query(on: request).all().wait().delete(on: request).wait()
		guard count > 0 else { return [] }
		let conn = request
		let ids: [Int] = Array(1...count)

		models = try ExampleModel.findOrCreateModels(ids: ids, on: conn)
		for model in models{
			let sibling: ExampleSiblingModel = try ExampleSiblingModel.findOrCreateModel(id: model.id!, on: conn)
			let _ = try model.siblings.attach(sibling, on: conn).wait()
			let child1: ExampleChildModel = try ExampleChildModel.createModel(on: conn)
			let child2: ExampleChildModel = try ExampleChildModel.createModel(on: conn)
			let children: [ExampleChildModel] = [child1, child2]
			try children.forEach { (child) in
				child.optionalParentModelId = model.id!
				let _ = try child.save(on: conn).wait()
			}
		}
		return models
	}

	func debugPrint(models: [ExampleModel]) throws{
		try models.forEach { (item) in
			try item.toAnyDictionary().printPretty()
		}
	}
	func debugPrint<M: Model>(page: CursorPage<M>) throws{
		try page.toAnyDictionary().printPretty()
	}
}

fileprivate extension Collection where Element: Model, Element.Database: QuerySupporting{

	fileprivate func delete(on conn: DatabaseConnectable)  -> Future<Void>{
		return map { $0.delete(on: conn) }.flatten(on: conn)
	}
}

