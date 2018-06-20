//
//  PaginationTests.swift
//  CursorPagination
//
//  Created by Brian Strobach on 12/28/17.
//

import Foundation
import XCTest
import FluentTestApp
import Vapor
import Fluent
import HTTP
import CodableExtended
import CursorPagination
import FluentSQLite



class CursorPaginationTests: CursorPaginationTestCase {

	//MARK: Linux Testing
	static var allTests = [
		("testLinuxTestSuiteIncludesAllTests", testLinuxTestSuiteIncludesAllTests),
		("testEmptyTable", testEmptyTable),
		("testLessThanPageLimit", testLessThanPageLimit),
		("testExactlyPageLimit", testExactlyPageLimit),
		("testDoublePageLimit", testDoublePageLimit),
		("testPartialFinalPage", testPartialFinalPage),
		("testIdAscendingSort", testIdAscendingSort),
		("testIdDescendingSort", testIdDescendingSort),
		("testBoolAscendingSort", testBoolAscendingSort),
		("testBoolDescendingSort", testBoolDescendingSort),
		("testStringAscendingSort", testStringAscendingSort),
		("testStringDescendingSort", testStringDescendingSort),
		("testDoubleAscendingSort", testDoubleAscendingSort),
		("testDoubleDescendingSort", testDoubleDescendingSort),
		("testDateAscendingSort", testDateAscendingSort),
		("testDateDescendingSort", testDateDescendingSort),
		("testOptionalStringAscendingSort", testOptionalStringAscendingSort),
		("testOptionalStringDescendingSort", testOptionalStringDescendingSort),
		("testComplexSortPagination", testComplexSortPagination)
	]

	func testLinuxTestSuiteIncludesAllTests(){
		assertLinuxTestCoverage(tests: type(of: self).allTests)
	}

//	Determines if test runs with various sizes of data. For most development purposes this can be false. This will minimize the time needed
//	to seed data and make the tests run much faster. Occasionally set to true when larger implementation changes are made, or before pushing
//	to repo. This will test various size data sets, testing against various edge cases. Much slower due to required reseeding of data between tests.

	#if os(Linux)
	var testAllEdgeCases = false //FIXME:: Setting this to true may break Linux test. Not sure why yet, just hangs.
	#else
	var testAllEdgeCases = true
	#endif

//	lazy var seedCounts = testAllEdgeCases ? [0, 1, 5, 10, 11] : [15]
	static let seedCount = 15
	let pageLimit = 5


	func debugPrint(sqlLiteQuery: FluentSQLiteQuery){
		Swift.debugPrint("QueryDescription: \(sqlLiteQuery)")
	}

	func testEmptyTable() throws{
		try runTest(seedCount: 0, sorts: [.descending(\.id)], orderTest: { (previousModel, model) -> Bool in
			return model.id! <= previousModel.id!
		})
	}

	func testLessThanPageLimit() throws{
		try runTest(seedCount: Int(Double(pageLimit)/2.0), sorts: [.descending(\.id)], orderTest: { (previousModel, model) -> Bool in
			return model.id! <= previousModel.id!
		})
	}

	func testExactlyPageLimit() throws{
		try runTest(seedCount: pageLimit, sorts: [.descending(\.id)], orderTest: { (previousModel, model) -> Bool in
			return model.id! <= previousModel.id!
		})
	}

	func testDoublePageLimit() throws{
		try runTest(seedCount: pageLimit * 2, sorts: [.descending(\.id)], orderTest: { (previousModel, model) -> Bool in
			return model.id! <= previousModel.id!
		})
	}

	func testPartialFinalPage() throws{
		try runTest(seedCount: (pageLimit * 2) + 1, sorts: [.descending(\.id)], orderTest: { (previousModel, model) -> Bool in
			return model.id! <= previousModel.id!
		})
	}

	func testIdAscendingSort() throws{
		try runTest(sorts: [.ascending(\.id)], orderTest: { (previousModel, model) -> Bool in
			return model.id! >= previousModel.id!
		})
	}

	func testIdDescendingSort() throws{
		try runTest(sorts: [.descending(\.id)], orderTest: { (previousModel, model) -> Bool in
			return model.id! <= previousModel.id!
		})
	}

	func testBoolAscendingSort() throws{
//		try debugPrint(models: try seedModels())
//
//		let sorts: [KeyPathSort<ExampleModel>] = [.ascending(\.booleanField)]
//		let builder = try ExampleModel.query(on: request).sortedForPagination(cursor: nil, sortFields: sorts)
//		debugPrint(sqlLiteQuery: builder.query)
//		let page = try ExampleModel.query(on: request).paginate(cursor: nil, sortFields: sorts).wait()
//		try debugPrint(models: page.data)
//		let builder2 = try ExampleModel.query(on: request).sortedForPagination(cursor: page.nextPageCursor, sortFields: sorts)
//		debugPrint(sqlLiteQuery: builder2.query)
//		let page2 = try ExampleModel.query(on: request).paginate(cursor: page.nextPageCursor, sortFields: sorts).wait()
//		try debugPrint(models: page2.data)

				try runTest(sorts: [.ascending(\.booleanField)], orderTest: { (previousModel, model) -> Bool in
					let lh = previousModel.booleanField
					let rh = model.booleanField
					return (lh == false && rh == true) || (lh == rh && previousModel.id! < model.id!)
				})
	}

	func testBoolDescendingSort() throws{
//		try seedModels()
//		let trueModels = try ExampleModel.query(on: request).filter(\.booleanField >= false).all().wait()
//		try debugPrint(models: trueModels)

		try runTest(sorts: [.descending(\.booleanField)], orderTest: { (previousModel, model) -> Bool in
			let lh = previousModel.booleanField
			let rh = model.booleanField
			return (lh == true && rh == false) || (lh == rh && previousModel.id! < model.id!)
		})
	}

	func testStringAscendingSort() throws {
		try runTest(sorts: [.ascending(\.stringField)], orderTest: { (previousModel, model) -> Bool in
			return model.stringField >= previousModel.stringField
		})
	}

	func testStringDescendingSort() throws {
		try runTest(sorts: [.descending(\.stringField)], orderTest: { (previousModel, model) -> Bool in
			return model.stringField <= previousModel.stringField
		})
	}

	func testDoubleAscendingSort() throws {
		try runTest(sorts: [.ascending(\.doubleField)], orderTest: { (previousModel, model) -> Bool in
			return  model.doubleField >= previousModel.doubleField
		})
	}

	func testDoubleDescendingSort() throws {
		try runTest(sorts: [.descending(\.doubleField)], orderTest: { (previousModel, model) -> Bool in
			return model.doubleField <= previousModel.doubleField
		})
	}

	func testDateAscendingSort() throws {
		#if !os(Linux) //FIXME: Another wierd issue where too many tests hang on linux, can remove this or any other test and it won't hang.
		try runTest(sorts: [.ascending(\.dateField)], orderTest: { (previousModel, model) -> Bool in
			return  model.dateField >= previousModel.dateField
		})
		#endif
	}
	func testDateDescendingSort() throws {
		#if !os(Linux) //FIXME: Another wierd issue where too many tests hang on linux, can remove this or any other test and it won't hang.
		try runTest(sorts: [.descending(\.dateField)], orderTest: { (previousModel, model) -> Bool in
			return model.dateField <= previousModel.dateField
		})
		#endif
	}


	func testOptionalStringAscendingSort() throws {
		try runTest(sorts: [.ascending(\.optionalStringField)], orderTest: { (previousModel, model) -> Bool in
			return optionalStringOrderTest(order: .ascending, model: model, previousModel: previousModel)
		})
	}

	func testOptionalStringDescendingSort() throws {
		try runTest(sorts: [.descending(\.optionalStringField)], orderTest: { (previousModel, model) -> Bool in
			return optionalStringOrderTest(order: .descending, model: model, previousModel: previousModel)
		})
	}

	internal func optionalStringOrderTest(order: KeyPathSortDirection<ExampleModel>, model: ExampleModel, previousModel: ExampleModel) -> Bool{

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



	func testComplexSortPagination() throws{
		try runTest(sorts: [.ascending(\.doubleField), .ascending(\.stringField)], orderTest: { (previousModel, model) -> Bool in
			let tiebreakerCase = model.doubleField == previousModel.doubleField && model.stringField >= previousModel.stringField
			let generalCase = model.doubleField > previousModel.doubleField
			return generalCase || tiebreakerCase
		})

		try runTest(sorts: [.ascending(\.doubleField), .ascending(\.stringField), .ascending(\.optionalStringField)], orderTest: { (previousModel, model) -> Bool in
			let generalOptionalStringCase = model.optionalStringField == nil
				|| previousModel.optionalStringField == nil
				|| model.optionalStringField! > previousModel.optionalStringField!
				|| (model.optionalStringField! == previousModel.optionalStringField! && model.id! > previousModel.id!)
			let doubleAndStringTieCase = model.doubleField == previousModel.doubleField
				&& model.stringField == previousModel.stringField
				&& generalOptionalStringCase

			let doubleTieCase = model.doubleField == previousModel.doubleField
				&& model.stringField > previousModel.stringField
			let doubleCase = model.doubleField > previousModel.doubleField
			return doubleAndStringTieCase || doubleTieCase || doubleCase
		})
	}

	func sortIds(for models: [ExampleModel]) -> [Int]{
		return models.map({$0.id!}).sorted()
	}


	func runTest(seedCount: Int = seedCount, sorts: [KeyPathSort<ExampleModel>], orderTest: OrderTest) throws{
		try runTest(seedCount: seedCount, pageFetcher: { (request, cursor, pageLimit) -> Future<CursorPage<ExampleModel>> in
			return try ExampleModel.paginate(on: request, cursor: cursor, count: pageLimit, sorts: sorts)
		}, orderTest: orderTest)
	}
	typealias OrderTest = (ExampleModel, ExampleModel) -> Bool
	typealias PageFetcher = (_ request: DatabaseConnectable, _ cursor: String?, _ count: Int) throws -> Future<CursorPage<ExampleModel>>

	func runTest(seedCount: Int = seedCount, pageFetcher: PageFetcher, orderTest: OrderTest) throws{
			let req = request
			if testAllEdgeCases{
				try ExampleModel.query(on: req).all().delete(on: req).wait()
			}
			let models: [ExampleModel] = try seedModels(seedCount)
			try debugPrint(models: models)
			let sortedIds: [Int] = sortIds(for: models)
			var cursor: String? = nil
			let total: Int = try ExampleModel.query(on: request).count().wait()
			var fetched: [ExampleModel] = []
			while fetched.count != total && total > 0{
				let page: CursorPage<ExampleModel> = try pageFetcher(request, cursor, pageLimit).wait()
				try debugPrint(page: page)
				cursor = page.nextPageCursor
				fetched.append(contentsOf: page.data)
				if cursor == nil { break }
			}


			for (i, model) in fetched.enumerated(){
				guard i > 0 else { continue }
				let previousModel = fetched[i - 1]
				let result = orderTest(previousModel, model)
				XCTAssertTrue(result)
			}
			XCTAssertEqual(sortedIds, sortIds(for: try! ExampleModel.query(on: request).all().wait()))

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

	fileprivate var duplicates: [Element] {

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



fileprivate extension Future where T: Collection, T.Element: Model, T.Element.Database: QuerySupporting{
	fileprivate func delete(on conn: DatabaseConnectable) -> Future<Void>{
		return flatMap(to: Void.self) { elements in
			return elements.delete(on: conn)
		}
	}
}

fileprivate extension Collection where Element: Model, Element.Database: QuerySupporting{
	fileprivate func delete(on conn: DatabaseConnectable)  -> Future<Void>{
		return map { $0.delete(on: conn) }.flatten(on: conn)
	}
}
