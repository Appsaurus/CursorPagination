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



class CursorPaginationTests: CursorPaginationTestCase {

	//MARK: Linux Testing
	static var allTests = [
		("testLinuxTestSuiteIncludesAllTests", testLinuxTestSuiteIncludesAllTests),
		("testComplexSortPagination", testComplexSortPagination),
		("testIdSortPagination", testIdSortPagination),
		("testBoolSortPagination", testBoolSortPagination),
		("testStringSortPagination", testStringSortPagination),
		("testOptionalStringSortPagination", testOptionalStringSortPagination),
		("testDoubleSortPagination", testDoubleSortPagination),
		("testDateSortPagination", testDateSortPagination)
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
	var testAllEdgeCases = false
	#endif

	lazy var seedCounts = testAllEdgeCases ? [0, 1, 5, 10, 11] : [15]
	var pageLimit = 5


	func testSimplePaginate() throws{
		let ids = Array(1...20)

//		let initializer = { () -> ExampleModel in
//			let model = ExampleModel()
//			model.optionalStringField = "optoinal"
//			return model
//		}
//		let models = try ExampleModel.findOrCreateModels(ids: ids, lazyConstructor: .custom(initializer: initializer), on: request)
		//		let found: CursorPage<ExampleModel> = try ExampleModel.paginate(on: request, cursor: nil, sorts: ExampleModel.defaultPageSorts).wait()

		let models = try ExampleModel.findOrCreateModels(ids: ids)
		try debugPrint(models: models)
		let results = try ExampleModel.query(on: request).paginate(cursor: nil, sortFields: ExampleModel.defaultPageSorts).wait()
		try debugPrint(page: results)
		if let nextPage = results.nextPageCursor{			
			let nextPageResults = try ExampleModel.query(on: request).paginate(cursor: nextPage, sortFields: ExampleModel.defaultPageSorts).wait()
			try debugPrint(page: nextPageResults)
		}
	}

	func testComplexSortPagination() throws{
		try runTest(with: [.ascending(\.booleanField), .ascending(\.stringField)], orderTest: { (previousModel, model) -> Bool in
			let generalCase = model.booleanField == previousModel.booleanField && model.stringField >= previousModel.stringField
			let boolTransitionEdgeCase = model.booleanField > previousModel.booleanField
			return generalCase || boolTransitionEdgeCase
		})

		try runTest(with: [.ascending(\.booleanField), .ascending(\.stringField), .ascending(\.optionalStringField)], orderTest: { (previousModel, model) -> Bool in
			let generalOptionalStringCase = model.optionalStringField == nil
					|| previousModel.optionalStringField == nil
					|| model.optionalStringField! > previousModel.optionalStringField!
					|| (model.optionalStringField! == previousModel.optionalStringField! && model.id! > previousModel.id!)
			let generalCase = model.booleanField == previousModel.booleanField
				&& model.stringField == previousModel.stringField
				&& generalOptionalStringCase

			let edgeCase1 = model.booleanField == previousModel.booleanField
				&& model.stringField > previousModel.stringField
			let edgeCase2 = model.booleanField > previousModel.booleanField
			return generalCase || edgeCase1 || edgeCase2
		})
	}

	func testIdSortPagination() throws{

		try runTest(with: [.ascending(\.id)], orderTest: { (previousModel, model) -> Bool in
			return model.id! >= previousModel.id!
		})
		try runTest(with: [.descending(\.id)], orderTest: { (previousModel, model) -> Bool in
			return model.id! <= previousModel.id!
		})
	}

	func testBoolSortPagination() throws{

		try runTest(with: [.ascending(\.booleanField)], orderTest: { (previousModel, model) -> Bool in
			return model.booleanField >= previousModel.booleanField
		})
		try runTest(with: [.descending(\.booleanField)], orderTest: { (previousModel, model) -> Bool in
			return model.booleanField <= previousModel.booleanField
		})
	}

	func testStringSortPagination() throws {

		try runTest(with: [.ascending(\.stringField)], orderTest: { (previousModel, model) -> Bool in
			return model.stringField >= previousModel.stringField
		})
		try runTest(with: [.descending(\.stringField)], orderTest: { (previousModel, model) -> Bool in
			return model.stringField <= previousModel.stringField
		})
	}

	func testOptionalStringSortPagination() throws {
		try runTest(with: [.ascending(\.optionalStringField)], orderTest: { (previousModel, model) -> Bool in
			return optionalStringOrderTest(order: .ascending, model: model, previousModel: previousModel)
		})

		try runTest(with: [.descending(\.optionalStringField)], orderTest: { (previousModel, model) -> Bool in
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

	func testDoubleSortPagination() throws {
		try runTest(with: [.ascending(\.doubleField)], orderTest: { (previousModel, model) -> Bool in
			return  model.doubleField >= previousModel.doubleField
		})
		try runTest(with: [.descending(\.doubleField)], orderTest: { (previousModel, model) -> Bool in
			return model.doubleField <= previousModel.doubleField
		})
	}

	func testDateSortPagination() throws {
		#if !os(Linux) //FIXME: Another wierd issue where too many tests hang on linux, can remove this or any other test and it won't hang.
		try runTest(with: [.ascending(\.dateField)], orderTest: { (previousModel, model) -> Bool in
			return  model.dateField >= previousModel.dateField
		})
		try runTest(with: [.descending(\.dateField)], orderTest: { (previousModel, model) -> Bool in
			return model.dateField <= previousModel.dateField
		})
		#endif
	}

	func sortIds(for models: [ExampleModel]) -> [Int]{
		return models.map({$0.id!}).sorted()
	}

	func runTest(with sorts: [KeyPathSort<ExampleModel>], orderTest: OrderTest) throws{
		try runTest(pageFetcher: { (request, cursor, pageLimit) -> Future<CursorPage<ExampleModel>> in
			return try ExampleModel.paginate(on: request, cursor: cursor, count: pageLimit, sorts: sorts)
		}, orderTest: orderTest)
	}

	typealias OrderTest = (ExampleModel, ExampleModel) -> Bool
	typealias PageFetcher = (_ request: DatabaseConnectable, _ cursor: String?, _ count: Int) throws -> Future<CursorPage<ExampleModel>>

	func runTest(pageFetcher: PageFetcher, orderTest: OrderTest) throws{
		let seedCounts = self.seedCounts
		for seedCount in seedCounts{
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
