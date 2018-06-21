//
//  QueryBuilder+CursorPagination.swift
//  CursorPagination
//
//  Created by Brian Strobach on 6/5/18.
//

import Foundation
import Fluent
import Vapor
import Codability
import CodableExtended

public typealias CursorBuilder<E: CursorPaginatable> = (E) throws -> String

////MARK: Main public API
extension QueryBuilder where Result: CursorPaginatable, Result.Database == Database {
	
	/// Paginates a query on the given sorts using opqaue cursors. More
	///
	/// - Parameters:
	///   - cursor: A cursor marking the start of the next page of results. If none is supplied, it is assumed that the query should start from the begining of the results, or the first page.
	///   - count: The page limit. Max number of items to return in one page.
	///   - sorts: The Sorts used to order the queries results. If there is only one sort, it must have uniquely indexable value. If the last sort in the array does not sort on a uniquely indexable field, then an additional sort will be applied. It will attempt to use the Result's default sort. If the models default sort is not uniquely indexable, it will use createdDate (if Timestampable) or the model ids to break ties.
	/// - Returns: A CursorPage<E> which contains the next page of results and a cursor for the next page if there are more results.
	public func paginate(cursor: String?,
						 count: Int = Result.defaultPageSize,
						 sortFields: [CursorSort<Result>]) throws -> Future<CursorPage<Result>> {
		var sorts = sortFields
		try ensureUniqueSort(sorts: &sorts)
		return try paginate(cursor: cursor, cursorBuilder: defaultCursorBuilder(sorts), count: count, sorts: sorts)
	}

	public func paginate(cursor: String?,
						 cursorBuilder: @escaping CursorBuilder<Result>,
						 count: Int = 20,
						 sorts: [CursorSort<Result>] = []) throws -> Future<CursorPage<Result>> {
		var sorts = sorts
		try ensureUniqueSort(sorts: &sorts)
		let query = try sortedForPagination(cursor: cursor, cursorBuilder: cursorBuilder, sorts: sorts)

		let copy = self.query
		let total: Future<Int> = self.count()
		self.query = copy

		let data: Future<[Result]> = query.range(...count).all()
		return map(to: CursorPage<Result>.self, data, total) { data, total in

			var data = data
			var nextPageCursor: String? = nil
			if data.count == count + 1, let nextFirstItem: Result = data.last{
				nextPageCursor = "\(try cursorBuilder(nextFirstItem).toBase64())"
				//Don't actually want to return this value yet, just getting its data to build the next cursor
				data.remove(at: data.count - 1)
			}

			return CursorPage(
				nextPageCursor: nextPageCursor,
				data: data,
				remaining: total - data.count
			)
		}
	}


	public func sortedForPagination(cursor: String?,
						 sortFields: [CursorSort<Result>]) throws -> QueryBuilder<Database, Result> {
		var sorts = sortFields
		try ensureUniqueSort(sorts: &sorts)
		return try sortedForPagination(cursor: cursor, cursorBuilder: defaultCursorBuilder(sorts), sorts: sorts)
	}

	public func sortedForPagination(cursor: String?,
						 cursorBuilder: @escaping CursorBuilder<Result>,
						 sorts: [CursorSort<Result>] = []) throws -> QueryBuilder<Database, Result> {
		var sorts = sorts
		try ensureUniqueSort(sorts: &sorts)
		try filter(cursor: cursor, sorts: sorts)
		sorts.forEach { (sort) in
			let _ = self.sort(sort.sort)
		}
		return self
	}

	// Filter out results before or after the cursor, depending upon order
	@discardableResult
	public func filter(cursor: String?, sorts: [CursorSort<Result>]) throws -> QueryBuilder<Database, Result>{
			guard let orderedCursorParts: [CursorPart] = try cursor?.toCursorParts() else {
				return self
			}

			guard orderedCursorParts.count == sorts.count else{
				throw Abort(.badRequest, reason: "That cursor does not does not match the sorts set for this query.")
			}

			debugPrint("Cursor decoded : \(orderedCursorParts.map({$0.field + " : " + ("\(String(describing: $0.value))")}))")
			guard orderedCursorParts.count > 0 else {
				throw Abort(.badRequest, reason: "This cursor has no parts.")
			}

			guard let tiebreakerCursorPart = orderedCursorParts.last, let tiebreakerSort: CursorSort<Result> = sorts.last, tiebreakerCursorPart.field == tiebreakerSort.propertyName else{
				throw Abort(.badRequest, reason: "Improperly formatted pagination query. Last cursor part does not match final sort.")
			}

			guard orderedCursorParts.count > 1 else{ //Must be a unique, single field sort. So, we only need to get the values greater than or equal to the cursor fields value.
				try filter(for: tiebreakerSort, startingAt: tiebreakerCursorPart)
				return self
			}

			guard orderedCursorParts.count > 2 else{//One nondistinct sort + one distinct tiebreaker sort
				let nonDistinctSort = sorts[0]
				let nonDistinctCursorPart = orderedCursorParts[0]
				return try filterForOptional(nonDistinctSort: nonDistinctSort,
								  nonDistinctCursorPart: nonDistinctCursorPart,
								  tiebreakerSort: tiebreakerSort,
								  tiebreakerCursorPart: tiebreakerCursorPart)

			}

			//There could be n nondistinct sorts + 1 final tiebreaker sort.
			//We must account for tiebreaks on each nondistinct sort.
			try group(Database.queryFilterRelationOr) { (or) in
				var cursorPartStack = orderedCursorParts
				var sortStack = sorts
				while cursorPartStack.count > 0{
//					guard cursorPartStack.count != 2 else{
//						let nonDistinctSort = sortStack[0]
//						let nonDistinctCursorPart = cursorPartStack[0]
//						let tiebreakerSort = sortStack[1]
//						let tiebreakerCursorPart = cursorPartStack[1]
//						try or.filterForOptional(nonDistinctSort: nonDistinctSort,
//												 nonDistinctCursorPart: nonDistinctCursorPart,
//												 tiebreakerSort: tiebreakerSort,
//												 tiebreakerCursorPart: tiebreakerCursorPart)
//						continue
//					}
					try or.group(Database.queryFilterRelationAnd){ (and) in
						let lastIndex = cursorPartStack.count - 1
						for i in 0...lastIndex{
							let part = cursorPartStack[i]
							guard i != lastIndex else{
								if sorts.count == cursorPartStack.count{
									try and.filter(for: sorts[i], startingAt: part)
								}
								else{
									try and.filter(for: sorts[i], startingAt: part, inclusive: false)
								}
								cursorPartStack.removeLast()
								sortStack.removeLast()
								continue
							}
							and.filter(sortStack[i].field, Database.queryFilterMethodEqual, part.value)
						}
					}
				}
			}
			return self
		}
		
		guard filterBuilders.count > 2 else{//One nondistinct sort + one distinct tiebreaker sort
			return try filterForOptional(nonDistinctFilter: filterBuilders[0], tieBreakerFilter: filterBuilders[1])
		}
		
		//There could be n nondistinct sorts + 1 final tiebreaker sort.
		//We must account for tiebreaks on each nondistinct sort.
		try group(Database.queryFilterRelationOr) { (or) in
			var filterPartStack = filterBuilders //Copy filter builders to a stack
			while filterPartStack.count > 0{
				//					guard cursorPartStack.count != 2 else{
				//						let nonDistinctSort = sortStack[0]
				//						let nonDistinctCursorPart = cursorPartStack[0]
				//						let tiebreakerSort = sortStack[1]
				//						let tiebreakerCursorPart = cursorPartStack[1]
				//						try or.filterForOptional(nonDistinctSort: nonDistinctSort,
				//												 nonDistinctCursorPart: nonDistinctCursorPart,
				//												 tiebreakerSort: tiebreakerSort,
				//												 tiebreakerCursorPart: tiebreakerCursorPart)
				//						continue
				//					}
				try or.group(Database.queryFilterRelationAnd){ (and) in
					let lastIndex = filterPartStack.count - 1
					for i in 0...lastIndex{
						let filter = filterPartStack[i]
						guard i != lastIndex else{
							if sorts.count == filterPartStack.count{
								try and.filter(for: filter)
							}
							else{
								try and.filter(for: filter, inclusive: false)
							}
							filterPartStack.removeLast()
							continue
						}
						and.filter(filter.sort.field, Database.queryFilterMethodEqual, filter.cursorPart.value)
					}
				}
			}
		}
		return self
		
	}
	
	
	@discardableResult
	public func filterForOptional(nonDistinctFilter: CursorFilterBuilder<Result>,
								  tieBreakerFilter: CursorFilterBuilder<Result>) throws -> QueryBuilder<Database, Result>{
		
		let nonDistinctSort: CursorSort<Result> = nonDistinctFilter.sort
		let nonDistinctCursorPart: CursorPart = nonDistinctFilter.cursorPart
		let tiebreakerSort: CursorSort<Result> = tieBreakerFilter.sort
		let tiebreakerCursorPart: CursorPart = tieBreakerFilter.cursorPart
		let nilValue: String? = nil
		if nonDistinctSort.fieldIsOptional{
			group(Database.queryFilterRelationOr) { (or) in
				if let value = nonDistinctCursorPart.value{
					or.group(Database.queryFilterRelationAnd, closure: { (and) in
						and.filter(nonDistinctSort.field, Database.queryFilterMethodEqual, value)
						and.filter(tiebreakerSort.field, self.filterMethod(for: tiebreakerSort.direction, inclusive: true), tiebreakerCursorPart.value)
					})
					switch nonDistinctSort.direction{
					case .ascending:
						or.filter(nonDistinctSort.field, Database.queryFilterMethodGreaterThan, value)
					case .descending:
						or.filter(nonDistinctSort.field, Database.queryFilterMethodLessThan, value)
						or.filter(nonDistinctSort.field, Database.queryFilterMethodEqual, nilValue)
					}
				}
				else{ //Nil nondistinct value
					switch nonDistinctSort.direction{
					case .ascending:
						or.group(Database.queryFilterRelationAnd, closure: { (and) in
							and.filter(nonDistinctSort.field, Database.queryFilterMethodEqual, nonDistinctCursorPart.value)
							and.filter(tiebreakerSort.field, self.filterMethod(for: tiebreakerSort.direction, inclusive: true), tiebreakerCursorPart.value)
						})
						or.filter(nonDistinctSort.field, Database.queryFilterMethodNotEqual, nonDistinctCursorPart.value)
					case .descending:
						self.group(Database.queryFilterRelationAnd, closure: { (and) in
							and.filter(nonDistinctSort.field, Database.queryFilterMethodEqual, nilValue)
							and.filter(tiebreakerSort.field, self.filterMethod(for: tiebreakerSort.direction, inclusive: true), tiebreakerCursorPart.value)
						})
					}
				}
			}
			return self
		}
		
		//Non optional
		try group(Database.queryFilterRelationOr) { (or) in
			try or.group(Database.queryFilterRelationAnd){ (and) in
				and.filter(nonDistinctSort.field, Database.queryFilterMethodEqual, nonDistinctCursorPart.value)
				try and.filter(for: tieBreakerFilter, inclusive: true)
			}
			try or.filter(for: nonDistinctFilter, inclusive: false)
		}
		return self
	}
	
	public func filterMethod(for direction: CursorSortDirection, inclusive: Bool = true) -> Database.QueryFilterMethod{
		switch (inclusive, direction){
		case (true, .ascending):
			return Database.queryFilterMethodGreaterThanOrEqual
		case (false, .ascending):
			return Database.queryFilterMethodGreaterThan
		case (true, .descending):
			return Database.queryFilterMethodLessThanOrEqual
		case (false, .descending):
			return Database.queryFilterMethodLessThan
		}
	}
	
	@discardableResult
	public func filter(for builder: CursorFilterBuilder<Result>, inclusive: Bool = true) throws -> QueryBuilder<Database, Result>{
		let method = filterMethod(for: builder.sort.direction, inclusive: inclusive)
		filter(builder.sort.field, method, builder.cursorPart.value)
		return self
	}
	public func ensureUniqueSort(sorts: inout [CursorSort<Result>]) throws {
		if sorts.count == 0 {
			sorts.append(contentsOf: Result.defaultPageSorts)
		}
		if sorts.count == 0 || sorts.last?.keyPath != Result.idKey{
			//Use id for tiebreakers on nonunique sorts //TODO: Check schema for uniqueness instead of always applying id as tiebreaker
			sorts.append(Result.idKey.ascendingSort)
		}
	}
	
	
	private func defaultCursorBuilder(_ sorts: [CursorSort<Result>]) throws -> CursorBuilder<Result>{
		let cursorBuilder: (Result) throws -> String = { (model: Result) in
			let cursorParts = sorts.map({ (sort) -> CursorPart in
				let value: Any = model[keyPath: sort.keyPath]
				//				print("Key: \(sort.propertyName)")
				//				print("Part Value: \(value)")
				return CursorPart(key: sort.propertyName, value: value, direction: sort.direction)
			})
			print("cursorParts: \(cursorParts)")
			return try cursorParts.encodeAsJSONString()
		}
		return cursorBuilder
	}
}





extension String{
	func arrayOfDictionariesFromJSONString() throws -> [AnyDictionary] {
		guard let data = data(using: .utf8) else{
			throw EncodingError.invalidValue(self, EncodingError.Context.init(codingPath: [], debugDescription: "Unable to convert string to utf8 data."))
		}
		
		guard let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [Any] else {
			throw EncodingError.invalidValue(self, EncodingError.Context.init(codingPath: [], debugDescription: "Unable to string to array of dictionaries."))
		}
		return jsonObject.map { $0 as! [String: Any] }
	}
	
	func arrayOfAnyCodableDictionariesFromJSONString() throws -> [AnyCodableDictionary]{
		return try arrayOfDictionariesFromJSONString().map({try $0.toAnyCodableDictionary()})
	}
}
