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

    func testEmptyTable() async throws{
        try await runTest(seedCount: 0, sorts: [.descending(\.$id)], orderTest: { (previousModel, model) -> Bool in
            return model.id! <= previousModel.id!
        })
    }

    func testLessThanPageLimit() async throws{
        try await runTest(seedCount: Int(Double(pageLimit)/2.0), sorts: [.descending(\.$id)], orderTest: { (previousModel, model) -> Bool in
            return model.id! <= previousModel.id!
        })
    }

    func testExactlyPageLimit() async throws{
        try await runTest(seedCount: pageLimit, sorts: [.descending(\.$id)], orderTest: { (previousModel, model) -> Bool in
            return model.id! <= previousModel.id!
        })
    }

    func testDoublePageLimit() async throws{
        try await runTest(seedCount: pageLimit * 2, sorts: [.descending(\.$id)], orderTest: { (previousModel, model) -> Bool in
            return model.id! <= previousModel.id!
        })
    }

    func testPartialFinalPage() async throws{
        try await runTest(seedCount: (pageLimit * 2) + 1, sorts: [.descending(\.$id)], orderTest: { (previousModel, model) -> Bool in
            return model.id! <= previousModel.id!
        })
    }

    func testIdAscendingSort() async throws{
        try await runTest(sorts: [.ascending(\.$id)], orderTest: { (previousModel, model) -> Bool in
            return model.id! >= previousModel.id!
        })
    }

    func testIdDescendingSort() async throws{
        try await runTest(sorts: [.descending(\.$id)], orderTest: { (previousModel, model) -> Bool in
            return model.id! <= previousModel.id!
        })
    }

    func testBoolAscendingSort() async throws{
        try await runTest(sorts: [.ascending(\.$booleanField)], orderTest: { (previousModel, model) -> Bool in
            let lh = previousModel.booleanField
            let rh = model.booleanField
            return (lh == false && rh == true) || (lh == rh && previousModel.id! < model.id!)
        })
    }

    func testBoolDescendingSort() async throws{

        try await runTest(sorts: [.descending(\.$booleanField)], orderTest: { (previousModel, model) -> Bool in
            let lh = previousModel.booleanField
            let rh = model.booleanField
            return (lh == true && rh == false) || (lh == rh && previousModel.id! < model.id!)
        })
    }

    func testStringAscendingSort() async throws {
        try await runTest(sorts: [.ascending(\.$stringField)], orderTest: { (previousModel, model) -> Bool in
            return model.stringField >= previousModel.stringField
        })
    }

    func testStringDescendingSort() async throws {
        try await runTest(sorts: [.descending(\.$stringField)], orderTest: { (previousModel, model) -> Bool in
            return model.stringField <= previousModel.stringField
        })
    }

    func testDoubleAscendingSort() async throws {
        try await runTest(sorts: [.ascending(\.$doubleField)], orderTest: { (previousModel, model) -> Bool in
            return  model.doubleField >= previousModel.doubleField
        })
    }

    func testDoubleDescendingSort() async throws {
        try await runTest(sorts: [.descending(\.$doubleField)], orderTest: { (previousModel, model) -> Bool in
            return model.doubleField <= previousModel.doubleField
        })
    }

    func testDateAscendingSort() async throws {
        try await runTest(sorts: [.ascending(\.$dateField)], orderTest: { (previousModel, model) -> Bool in
            return  model.dateField >= previousModel.dateField
        })
    }
    func testDateDescendingSort() async throws {
        try await runTest(sorts: [.descending(\.$dateField)], orderTest: { (previousModel, model) -> Bool in
            return model.dateField <= previousModel.dateField
        })
    }


    func testOptionalStringAscendingSort() async throws {
        try await runTest(sorts: [.ascending(\.$optionalStringField)], orderTest: { (previousModel, model) -> Bool in
            return optionalStringOrderTest(order: .ascending, model: model, previousModel: previousModel)
        })
    }

    func testOptionalStringDescendingSort() async throws {
        try await runTest(sorts: [.descending(\.$optionalStringField)], orderTest: { (previousModel, model) -> Bool in
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



    func testCompoundNonUniqueSort() async throws{
        try await runTest(sorts: [.ascending(\.$doubleField), .ascending(\.$stringField)], orderTest: { (previousModel, model) -> Bool in
            let tiebreakerCase = model.doubleField == previousModel.doubleField && model.stringField >= previousModel.stringField
            let generalCase = model.doubleField > previousModel.doubleField
            return generalCase || tiebreakerCase
        })
    }

    func testComplexSort() async throws{
        try await runTest(sorts: [.ascending(\.$doubleField), .ascending(\.$stringField), .ascending(\.$optionalStringField)], orderTest: { (previousModel, model) -> Bool in
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

    func testBoolComplexSort() async throws{
        try await runTest(sorts: [.ascending(\.$booleanField), .ascending(\.$intField)], orderTest: { (previousModel, model) -> Bool in
            let lh = previousModel.booleanField
            let rh = model.booleanField
            let uniqueSortOption = (lh == false && rh == true)
            let intTiebreaker = (lh == rh && previousModel.intField < model.intField)
            let idTiebreaker = (lh == rh && previousModel.intField == model.intField && previousModel.id! < model.id!)
            return uniqueSortOption || intTiebreaker || idTiebreaker
        })
    }

    func testBoolComplexSortDescending() async throws{
        try await runTest(sorts: [.descending(\.$booleanField), .ascending(\.$intField)], orderTest: { (previousModel, model) -> Bool in
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

    func runTest(seedCount: Int = seedCount, sorts: [CursorSort<KitchenSink>], orderTest: OrderTest) async throws {
        try await runTest(seedCount: seedCount, pageFetcher: { (request, cursor, pageLimit) async throws -> CursorPage<KitchenSink> in
            return try await KitchenSink.paginate(on: request, cursor: cursor, limit: pageLimit, sorts: sorts)
        }, orderTest: orderTest)
    }
    
    typealias OrderTest = (KitchenSink, KitchenSink) -> Bool
    typealias PageFetcher = (_ database: Database, _ cursor: String?, _ count: Int) async throws -> CursorPage<KitchenSink>

    func runTest(seedCount: Int = seedCount, pageFetcher: PageFetcher, orderTest: OrderTest) async throws {
        let database = app.db
        try await KitchenSink.query(on: database).all().delete(on: database)
        try await seedModels(seedCount)
        let sortedIds: [Int] = seedCount < 1 ? [] : Array<Int>(1...seedCount)
        var cursor: String? = nil
        let total = try await KitchenSink.query(on: database).count()
        var fetched: [KitchenSink] = []
        
        while fetched.count != total && total > 0 {
            let page: CursorPage<KitchenSink> = try await pageFetcher(database, cursor, pageLimit)
            cursor = page.nextPageCursor
            fetched.append(contentsOf: page.data)
            if cursor == nil { break }
        }

        for (i, model) in fetched.enumerated() {
            guard i > 0 else { continue }
            let previousModel = fetched[i - 1]
            let result = orderTest(previousModel, model)
            if result == false {
                print("Assertion failed for order test between previous model:")
                try previousModel.toAnyDictionary().printPrettyJSONString()
                print("and model:")
                try model.toAnyDictionary().printPrettyJSONString()
            }
            XCTAssertTrue(result)
        }
        
        let allModels = try await KitchenSink.query(on: database).all()
        XCTAssertEqual(sortedIds, sortIds(for: allModels))
        XCTAssertEqual(sortedIds.count, fetched.count)
        
        let sortedResultIds = sortIds(for: fetched)
        XCTAssertEqual(sortedIds, sortedResultIds)
        let expectedSet = Set(sortedIds)
        let resultSet = Set(sortedResultIds)
        let missingExpected = expectedSet.subtracting(resultSet)
        
        if missingExpected.count > 0 {
            XCTFail("Missing expected results with ids \(missingExpected)")
        }

        let unexpected = resultSet.subtracting(expectedSet)
        if unexpected.count > 0 {
            XCTFail("Unexpected results with ids \(unexpected)")
        }

        let duplicates = sortedResultIds.duplicates
        if duplicates.count > 0 {
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
