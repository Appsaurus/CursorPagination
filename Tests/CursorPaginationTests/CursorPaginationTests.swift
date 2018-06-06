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



class CursorPaginationTests: PaginationTestCase {

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


	// Determines if test runs with various sizes of data. For most development purposes this can be false. This will minimize the time
	// needed to seed data and make the tests run much faster. Occasionally set to true when larger implementation changes are made, or before pushing
	// to repo. This will test various size data sets, testing against various edge cases. Much slower due to required reseeding of data between tests.
	var testAllEdgeCases = true

	lazy var seedCounts = testAllEdgeCases ? [0, 1, 5, 10, 11, 20, 21] : [10]
	var pageLimit = 5

	override func setupOnce() throws {
		try super.setupOnce()
		//If only testing one seed size, no need to reseed for each test.
		if !testAllEdgeCases{
			CursorPaginationTests.persistApplicationBetweenTests = true
			try seedModels(seedCounts.first!)
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

	internal func optionalStringOrderTest(order: QuerySortDirection, model: ExampleModel, previousModel: ExampleModel) -> Bool{
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

		try runTest(with: [.ascending(\.dateField)], orderTest: { (previousModel, model) -> Bool in
			return  model.dateField >= previousModel.dateField
		})
		try runTest(with: [.descending(\.dateField)], orderTest: { (previousModel, model) -> Bool in
			return model.dateField <= previousModel.dateField
		})
	}

	typealias OrderTest = (ExampleModel, ExampleModel) -> Bool
	typealias PageFetcher = (_ request: DatabaseConnectable, _ cursor: String?, _ count: Int) throws -> CursorPage<ExampleModel>
	func runTest(onSeedsOfSizes seedCounts: [Int]? = nil, pageFetcher: PageFetcher, orderTest: OrderTest) throws{
		var seedCounts = seedCounts ?? self.seedCounts
		for seedCount in seedCounts{
			func sortIds(for models: [ExampleModel]) -> [Int]{
				return models.map({$0.id!}).sorted()
			}

			let models: [ExampleModel] = try seedModels(seedCount)
			let sortedIds: [Int] = sortIds(for: models)
			var cursor: String? = nil
			let total: Int = try ExampleModel.query(on: request).count().wait()
			var fetched: [ExampleModel] = []
			while fetched.count != total{
				let page: CursorPage<ExampleModel> = try pageFetcher(request, cursor, pageLimit)
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

	func runTest(onSeedsOfSizes seedCounts: [Int]? = nil, with sorts: [KeyPathSort<ExampleModel>], orderTest: OrderTest) throws{
		try runTest(onSeedsOfSizes: seedCounts, pageFetcher: { (request, cursor, pageLimit) -> CursorPage<ExampleModel> in
			return try ExampleModel.paginate(on: request, cursor: cursor, count: pageLimit, sorts: sorts).wait()
		}, orderTest: orderTest)
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





