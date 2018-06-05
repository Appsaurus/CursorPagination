//
//  PaginationTests.swift
//  ServasaurusTests
//
//  Created by Brian Strobach on 12/28/17.
//

import Foundation
import XCTest
@testable import Vapor
import HTTP
import Fluent
import VaporTestUtils
import FluentTestApp
import HTTP
import FluentTestUtils
//import ServasaurusExampleApp
//import DinoDNA
import Random
import Pagination
@testable import CursorPagination
//import SQLite


extension ExampleModel: CursorPaginatable{}
extension ExampleChildModel: CursorPaginatable{}
extension ExampleSiblingModel: CursorPaginatable{}


class PaginationTests: FluentTestAppTestCase {

	//MARK: Linux Testing
	static var allTests = [
		("testLinuxTestSuiteIncludesAllTests", testLinuxTestSuiteIncludesAllTests),
		("testOffsetPagination", testOffsetPagination),
		("testComplexSortPagination", testComplexSortPagination),
		("testIdSortPagination", testIdSortPagination),
		("testBoolSortPagination", testBoolSortPagination),
		("testStringSortPagination", testStringSortPagination),
		("testOptionalStringSortPagination", testOptionalStringSortPagination),
		("testDateSortPagination", testDateSortPagination),
		]

	func testLinuxTestSuiteIncludesAllTests(){
		assertLinuxTestCoverage(tests: type(of: self).allTests)
	}


	var pageLimit = 20
	var seedCounts = [20]// [0, 1, 5, 10, 15, 20, 35, 40]

	//	let idSort = try! CursorPaginationSort(ExampleModel.idKey)
	//	let descendingIdSort = try! CursorPaginationSort(ExampleModel.idKey, .descending)
	//	let dateSort = try!CursorPaginationSort(\ExampleModel.dateField, .ascending)
	//	let descendingDateSort = try! CursorPaginationSort(\ExampleModel.dateField, .descending)
	//	let boolSort = try! CursorPaginationSort(\ExampleModel.booleanField, .ascending)
	//	let descendingBoolSort = try! CursorPaginationSort(\ExampleModel.booleanField, .descending)
	//	let stringSort = try! CursorPaginationSort(\ExampleModel.stringField, .ascending)
	//	let descendingStringSort = try! CursorPaginationSort(\ExampleModel.stringField, .descending)
	//	let optionalStringSort = try! CursorPaginationSort(\ExampleModel.optionalStringField, .ascending)
	//	let descendingOptionalStringSort = try! CursorPaginationSort(\ExampleModel.optionalStringField, .descending)


	let idSort = QuerySort(field: "id", direction: .ascending)
	let descendingIdSort = QuerySort(field: "id", direction: .descending)
//	let descendingIdSort = try! QuerySort(ExampleModel.idKey, .descending)
	let dateSort = QuerySort(field: "dateField", direction: .ascending)
	let descendingDateSort = QuerySort(field: "dateField", direction: .descending)
	let boolSort = QuerySort(field: "booleanField", direction: .ascending)
	let descendingBoolSort = QuerySort(field: "booleanField", direction: .descending)
	let stringSort = QuerySort(field: "stringField", direction: .ascending)
	let descendingStringSort = QuerySort(field: "stringField", direction: .descending)
	let optionalStringSort = QuerySort(field: "optionalStringField", direction: .ascending)
	let descendingOptionalStringSort = QuerySort(field: "optionalStringField", direction: .descending)



	override func setupOnce() throws {
		try super.setupOnce()
	}

	func testOffsetPagination() throws{
		let idSort = QuerySort(field: "id", direction: .ascending)
		let totalCount = 20
		try seedModels(totalCount)
		let total: Int = try ExampleModel.query(on: request).count().wait()
		var fetched: [ExampleModel] = []
		var pageNumber: Int = 1
		while fetched.count != total{
			let page: Page<ExampleModel> = try ExampleModel.query(on: request).paginate(page: pageNumber, per: pageLimit, [idSort]).wait()
			fetched.append(contentsOf: page.data)
			pageNumber += 1
			testLog(page.response())
		}

		XCTAssertEqual(Array(1...totalCount), fetched.map({$0.id!}).sorted())
	}


	func testComplexSortPagination() throws{

		try runTest(with: [boolSort, stringSort], orderTest: { (previousModel, model) -> Bool in
			let generalCase = model.booleanField == previousModel.booleanField && model.stringField >= previousModel.stringField
			let boolTransitionEdgeCase = model.booleanField > previousModel.booleanField
			return generalCase || boolTransitionEdgeCase
		})

		try runTest(with: [self.boolSort, self.stringSort, self.optionalStringSort], orderTest: { (previousModel, model) -> Bool in
			let generalOptionalStringCase = model.optionalStringField == nil || previousModel.optionalStringField == nil || model.optionalStringField! > previousModel.optionalStringField! || (model.optionalStringField! == previousModel.optionalStringField! && model.id! > previousModel.id!)
			let generalCase = model.booleanField == previousModel.booleanField && model.stringField == previousModel.stringField && generalOptionalStringCase
			let edgeCase1 = model.booleanField == previousModel.booleanField && model.stringField > previousModel.stringField
			let edgeCase2 = model.booleanField > previousModel.booleanField
			return generalCase || edgeCase1 || edgeCase2
		})
	}

	func testIdSortPagination() throws{
		try runTest(with: [self.idSort], orderTest: { (previousModel, model) -> Bool in
			return model.id! >= previousModel.id!
		})
		try runTest(with: [self.descendingIdSort], orderTest: { (previousModel, model) -> Bool in
			return model.id! <= previousModel.id!
		})
	}

	func testBoolSortPagination() throws{
		try runTest(with: [self.boolSort], orderTest: { (previousModel, model) -> Bool in
			return model.booleanField >= previousModel.booleanField
		})
		try runTest(with: [self.descendingBoolSort], orderTest: { (previousModel, model) -> Bool in
			return model.booleanField <= previousModel.booleanField
		})
	}

	func testStringSortPagination() throws {

		let stringField = \ExampleModel.stringField
		try runTest(with: [.sort(stringField)], orderTest: { (previousModel, model) -> Bool in
			return model.stringField >= previousModel.stringField
		})
		try runTest(with: [.sort(stringField, .descending)], orderTest: { (previousModel, model) -> Bool in
			return model.stringField <= previousModel.stringField
		})

		try runTest(with: [self.stringSort], orderTest: { (previousModel, model) -> Bool in
			return model.stringField >= previousModel.stringField
		})
		try runTest(with: [self.descendingStringSort], orderTest: { (previousModel, model) -> Bool in
			return model.stringField <= previousModel.stringField
		})
	}

	func testOptionalStringSortPagination() throws {
		let optionalStringKey = \ExampleModel.optionalStringField
		try runTest(with: [.sort(optionalStringKey)], orderTest: { (previousModel, model) -> Bool in
			return optionalStringOrderTest(order: .ascending, model: model, previousModel: previousModel)
		})

		try runTest(with: [.sort(optionalStringKey, .descending)], orderTest: { (previousModel, model) -> Bool in
			return optionalStringOrderTest(order: .descending, model: model, previousModel: previousModel)
		})

		try runTest(with: [self.optionalStringSort], orderTest: { (previousModel, model) -> Bool in
			return optionalStringOrderTest(order: .ascending, model: model, previousModel: previousModel)
		})

		try runTest(with: [self.descendingOptionalStringSort], orderTest: { (previousModel, model) -> Bool in
			return optionalStringOrderTest(order: .descending, model: model, previousModel: previousModel)
		})
//		let all: [ExampleModel] = try ExampleModel.query(on: request).all().wait()
		//		debugPrint(models: all)
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


	func testDateSortPagination() throws {

		try runTest(with: [self.dateSort], orderTest: { (previousModel, model) -> Bool in
			return  model.dateField >= previousModel.dateField
		})
		try runTest(with: [self.descendingDateSort], orderTest: { (previousModel, model) -> Bool in
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
				//				print(try page.toJsonDictionary().prettyPrinted)
				//			debugPrint(models: page.data)
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

//			let duplicates = sortedResultIds.duplicates
//			if duplicates.count > 0{
//				XCTFail("Unexpected duplicates with ids \(duplicates)")
//			}
		}
	}


	func runTest(onSeedsOfSizes seedCounts: [Int]? = nil, with sorts: [QuerySort], orderTest: OrderTest) throws{
		try runTest(onSeedsOfSizes: seedCounts, pageFetcher: { (request, cursor, pageLimit) -> CursorPage<ExampleModel> in
			return try ExampleModel.paginate(on: request, cursor: cursor, count: pageLimit, sorts: sorts).wait()
		}, orderTest: orderTest)
	}

	func runTest(onSeedsOfSizes seedCounts: [Int]? = nil, with sorts: [CursorPaginationSort<ExampleModel>], orderTest: OrderTest) throws{
		try runTest(onSeedsOfSizes: seedCounts, pageFetcher: { (request, cursor, pageLimit) -> CursorPage<ExampleModel> in
			return try ExampleModel.paginate(on: request, cursor: cursor, count: pageLimit, sortFields: sorts).wait()
		}, orderTest: orderTest)
	}

	private func debugPrint(models: [ExampleModel]){
		models.forEach { (item) in

			print("\nId: \(item.id!)" +
				"\nDate: " + item.dateField.string_iso8601 //+
				//								"\nCreated at: " + item.createdAt!.string_iso8601 +
				//								"\nString: " + item.stringField +
				//				"\nOptionalString: " + String(describing: item.optionalStringField) +
				//								"\nBool: \(item.booleanField)\n"
			)
		}
	}

	@discardableResult
	func seedModels(_ count: Int = 30) throws -> [ExampleModel] {
		try! ExampleModel.query(on: request).all().wait().delete(on: request).wait()
		guard count > 0 else { return [] }
		let conn = request
		//		var models: [ExampleModel] = []
		let ids: [Int] = Array(1...count)

		let models = try ExampleModel.findOrCreateModels(ids: ids, on: conn)
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
			//			models.append(model)
		}
		return models
	}
}

fileprivate extension Collection where Element: Model, Element.Database: QuerySupporting{

	fileprivate func delete(on conn: DatabaseConnectable)  -> Future<Void>{
		return map { $0.delete(on: conn) }.flatten(on: conn)
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


