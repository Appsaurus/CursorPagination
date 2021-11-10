//
//  PaginationTests.swift
//  CursorPagination
//
//  Created by Brian Strobach on 12/28/17.
//

import Foundation
import XCTest
import FluentTestModels
import Vapor
import Fluent
import CodableExtensions
import CursorPagination
import FluentSQLiteDriver
import FluentTestModels
import FluentExtensions
class CursorPaginationTests: CursorPaginationTestCase {

	static let seedCount = 2
	let pageLimit = 4

	func testEmptyTable() throws{
        try runTest(seedCount: 0, sorts: [.descending(\.$id)], orderTest: { (previousModel, model) -> Bool in
			return model.id! <= previousModel.id!
		})
	}

	func testLessThanPageLimit() throws{
		try runTest(seedCount: Int(Double(pageLimit)/2.0), sorts: [.descending(\.$id)], orderTest: { (previousModel, model) -> Bool in
			return model.id! <= previousModel.id!
		})
	}

	func testExactlyPageLimit() throws{
		try runTest(seedCount: pageLimit, sorts: [.descending(\.$id)], orderTest: { (previousModel, model) -> Bool in
			return model.id! <= previousModel.id!
		})
	}

	func testDoublePageLimit() throws{
		try runTest(seedCount: pageLimit * 2, sorts: [.descending(\.$id)], orderTest: { (previousModel, model) -> Bool in
			return model.id! <= previousModel.id!
		})
	}

	func testPartialFinalPage() throws{
		try runTest(seedCount: (pageLimit * 2) + 1, sorts: [.descending(\.$id)], orderTest: { (previousModel, model) -> Bool in
			return model.id! <= previousModel.id!
		})
	}

	func testIdAscendingSort() throws{
		try runTest(sorts: [.ascending(\.$id)], orderTest: { (previousModel, model) -> Bool in
			return model.id! >= previousModel.id!
		})
	}

	func testIdDescendingSort() throws{
		try runTest(sorts: [.descending(\.$id)], orderTest: { (previousModel, model) -> Bool in
			return model.id! <= previousModel.id!
		})
	}

	func testBoolAscendingSort() throws{
		try runTest(sorts: [.ascending(\.$booleanField)], orderTest: { (previousModel, model) -> Bool in
			let lh = previousModel.booleanField
			let rh = model.booleanField
			return (lh == false && rh == true) || (lh == rh && previousModel.id! < model.id!)
		})
	}

	func testBoolDescendingSort() throws{

		try runTest(sorts: [.descending(\.$booleanField)], orderTest: { (previousModel, model) -> Bool in
			let lh = previousModel.booleanField
			let rh = model.booleanField
			return (lh == true && rh == false) || (lh == rh && previousModel.id! < model.id!)
		})
	}

	func testStringAscendingSort() throws {
		try runTest(sorts: [.ascending(\.$stringField)], orderTest: { (previousModel, model) -> Bool in
			return model.stringField >= previousModel.stringField
		})
	}

	func testStringDescendingSort() throws {
		try runTest(sorts: [.descending(\.$stringField)], orderTest: { (previousModel, model) -> Bool in
			return model.stringField <= previousModel.stringField
		})
	}

	func testDoubleAscendingSort() throws {
		try runTest(sorts: [.ascending(\.$doubleField)], orderTest: { (previousModel, model) -> Bool in
			return  model.doubleField >= previousModel.doubleField
		})
	}

	func testDoubleDescendingSort() throws {
		try runTest(sorts: [.descending(\.$doubleField)], orderTest: { (previousModel, model) -> Bool in
			return model.doubleField <= previousModel.doubleField
		})
	}

	func testDateAscendingSort() throws {
		try runTest(sorts: [.ascending(\.$dateField)], orderTest: { (previousModel, model) -> Bool in
			return  model.dateField >= previousModel.dateField
		})
	}
	func testDateDescendingSort() throws {
		try runTest(sorts: [.descending(\.$dateField)], orderTest: { (previousModel, model) -> Bool in
			return model.dateField <= previousModel.dateField
		})
	}


	func testOptionalStringAscendingSort() throws {
		try runTest(sorts: [.ascending(\.$optionalStringField)], orderTest: { (previousModel, model) -> Bool in
			return optionalStringOrderTest(order: .ascending, model: model, previousModel: previousModel)
		})
	}

	func testOptionalStringDescendingSort() throws {
		try runTest(sorts: [.descending(\.$optionalStringField)], orderTest: { (previousModel, model) -> Bool in
			return optionalStringOrderTest(order: .descending, model: model, previousModel: previousModel)
		})
	}

	internal func optionalStringOrderTest(order: QuerySortDirection, model: KitchenSink, previousModel: KitchenSink) -> Bool{

		let allNilCase = (model.optionalStringField == nil && previousModel.optionalStringField == nil)

		switch order{
		case .ascending:
			let nilTransitionCase = previousModel.optionalStringField == nil && model.optionalStringField != nil
			return (allNilCase || nilTransitionCase || model.optionalStringField! >= previousModel.optionalStringField!)
		case .descending:
			let nilTransitionCase = model.optionalStringField == nil && previousModel.optionalStringField != nil
			return (allNilCase || nilTransitionCase || model.optionalStringField! <= previousModel.optionalStringField!)
		}
	}



	func testCompoundNonUniqueSort() throws{
		try runTest(sorts: [.ascending(\.$doubleField), .ascending(\.$stringField)], orderTest: { (previousModel, model) -> Bool in
			let tiebreakerCase = model.doubleField == previousModel.doubleField && model.stringField >= previousModel.stringField
			let generalCase = model.doubleField > previousModel.doubleField
			return generalCase || tiebreakerCase
		})
	}

	func testComplexSort() throws{
		try runTest(sorts: [.ascending(\.$doubleField), .ascending(\.$stringField), .ascending(\.$optionalStringField)], orderTest: { (previousModel, model) -> Bool in
			let generalOptionalStringCase = model.optionalStringField == nil
				|| previousModel.optionalStringField == nil
				|| model.optionalStringField! > previousModel.optionalStringField!
				|| (model.optionalStringField! == previousModel.optionalStringField! && previousModel.id! < model.id!)
			let doubleAndStringTieCase = model.doubleField == previousModel.doubleField
				&& model.stringField == previousModel.stringField
				&& generalOptionalStringCase

			let doubleTieCase = model.doubleField == previousModel.doubleField
				&& model.stringField > previousModel.stringField
			let doubleCase = model.doubleField > previousModel.doubleField
			return doubleAndStringTieCase || doubleTieCase || doubleCase
		})
	}

    func testBoolComplexSort() throws{
        try runTest(sorts: [.ascending(\.$booleanField), .ascending(\.$intField)], orderTest: { (previousModel, model) -> Bool in
            let lh = previousModel.booleanField
            let rh = model.booleanField
            let uniqueSortOption = (lh == false && rh == true)
            let intTiebreaker = (lh == rh && previousModel.intField < model.intField)
            let idTiebreaker = (lh == rh && previousModel.intField == model.intField && previousModel.id! < model.id!)
            return uniqueSortOption || intTiebreaker || idTiebreaker
        })
    }

    func testBoolComplexSortDescending() throws{
        try runTest(sorts: [.descending(\.$booleanField), .ascending(\.$intField)], orderTest: { (previousModel, model) -> Bool in
            let lh = previousModel.booleanField
            let rh = model.booleanField
            let uniqueSortOption = (lh == true && rh == false)
            let intTiebreaker = (lh == rh && previousModel.intField < model.intField)
            let idTiebreaker = (lh == rh && previousModel.intField == model.intField && previousModel.id! < model.id!)
            return uniqueSortOption || intTiebreaker || idTiebreaker
        })
    }

	func sortIds(for models: [KitchenSink]) -> [Int]{
		return models.map({$0.id!}).sorted()
	}


	func runTest(seedCount: Int = seedCount, sorts: [CursorSort<KitchenSink>], orderTest: OrderTest) throws{
		try runTest(seedCount: seedCount, pageFetcher: { (request, cursor, pageLimit) -> Future<CursorPage<KitchenSink>> in
            return try KitchenSink.paginate(on: request, cursor: cursor, limit: pageLimit, sorts: sorts)
		}, orderTest: orderTest)
	}
	typealias OrderTest = (KitchenSink, KitchenSink) -> Bool
	typealias PageFetcher = (_ database: Database, _ cursor: String?, _ count: Int) throws -> Future<CursorPage<KitchenSink>>

	func runTest(seedCount: Int = seedCount, pageFetcher: PageFetcher, orderTest: OrderTest) throws{

            let database = app.db
			try KitchenSink.query(on: database).all().delete(on: database).wait()
			try seedModels(seedCount)
			let sortedIds: [Int] = seedCount < 1 ? [] : Array<Int>(1...seedCount)
			var cursor: String? = nil
			let total: Int = try KitchenSink.query(on: database).count().wait()
			var fetched: [KitchenSink] = []
			while fetched.count != total && total > 0{
				let page: CursorPage<KitchenSink> = try pageFetcher(database, cursor, pageLimit).wait()
//                try debugPrint(page: page)
				cursor = page.nextPageCursor
				fetched.append(contentsOf: page.data)
				if cursor == nil { break }
			}

			for (i, model) in fetched.enumerated(){
				guard i > 0 else { continue }
				let previousModel = fetched[i - 1]
				let result = orderTest(previousModel, model)
                if result == false {
                    print("Assertion failed for order test between previous model:")
                    try! previousModel.toAnyDictionary().printPrettyJSONString()
                    print("and model:")
                    try! model.toAnyDictionary().printPrettyJSONString()
                }
                XCTAssertTrue(result)
			}
			XCTAssertEqual(sortedIds, sortIds(for: try! KitchenSink.query(on: database).all().wait()))

			XCTAssertEqual(sortedIds.count, fetched.count)
			let sortedResultIds = sortIds(for: fetched)
			XCTAssertEqual(sortedIds, sortedResultIds)
			let expectedSet = Set(sortedIds)
			let resultSet = Set(sortedResultIds)
			let missingExpected = expectedSet.subtracting(resultSet)
			if missingExpected.count > 0{
				XCTFail("Missing expected results with ids \(missingExpected)")
			}

			let unexpected = resultSet.subtracting(expectedSet)
			if unexpected.count > 0{
				XCTFail("Unexpected results with ids \(unexpected)")
			}

			let duplicates = sortedResultIds.duplicates
			if duplicates.count > 0{
				XCTFail("Unexpected duplicates with ids \(duplicates)")
			}
		}
}


fileprivate extension Array where Element: Comparable & Hashable {

    var duplicates: [Element] {

		let sortedElements = sorted { $0 < $1 }
		var duplicatedElements = Set<Element>()

		var previousElement: Element?
		for element in sortedElements {
			if previousElement == element {
				duplicatedElements.insert(element)
			}
			previousElement = element
		}

		return Array(duplicatedElements)
	}
}



fileprivate extension Future where Value: Collection, Value.Element: Model{
    func delete(on conn: Database) -> Future<Void>{
		return flatMap { elements in
			return elements.delete(on: conn)
		}
	}
}

fileprivate extension Collection where Element: Model{
    func delete(on conn: Database)  -> Future<Void>{
        return map { $0.delete(on: conn) }.flatten(on: conn.eventLoop)
	}
}
