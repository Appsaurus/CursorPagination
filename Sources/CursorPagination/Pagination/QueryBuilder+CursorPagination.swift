//
//  QueryBuilder+CursorPagination.swift
//  CursorPagination
//
//  Created by Brian Strobach on 6/5/18.
//

import Foundation
import Fluent
import Vapor

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
						 sortFields: [KeyPathSort<Result>]) throws -> Future<CursorPage<Result>> {
		var sorts = sortFields
		try ensureUniqueSort(sorts: &sorts)
		return try paginate(cursor: cursor, cursorBuilder: defaultCursorBuilder(sorts), count: count, sorts: sorts)
	}

	public func paginate(cursor: String?,
						 cursorBuilder: @escaping CursorBuilder<Result>,
						 count: Int = 20,
						 sorts: [KeyPathSort<Result>] = []) throws -> Future<CursorPage<Result>> {
		var sorts = sorts
		try ensureUniqueSort(sorts: &sorts)
		let query = try sortedForPagination(cursor: cursor, cursorBuilder: cursorBuilder, sorts: sorts)

		let copy = self.query
		let total: Future<Int> = self.count()
		self.query = copy
		//Fetch our data plus the first item of the next page
		let limitIncludingNextItem = count + 1
		let data: Future<[Result]> = query.range(...limitIncludingNextItem).all()
		return map(to: CursorPage<Result>.self, data, total) { data, total in

			var data = data
			var nextPageCursor: String? = nil
			if data.count == limitIncludingNextItem, let nextFirstItem: Result = data.last{
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
						 sortFields: [KeyPathSort<Result>]) throws -> QueryBuilder<Database, Result> {
		var sorts = sortFields
		try ensureUniqueSort(sorts: &sorts)
		return try sortedForPagination(cursor: cursor, cursorBuilder: defaultCursorBuilder(sorts), sorts: sorts)
	}

	public func sortedForPagination(cursor: String?,
						 cursorBuilder: @escaping CursorBuilder<Result>,
						 sorts: [KeyPathSort<Result>] = []) throws -> QueryBuilder<Database, Result> {
		var sorts = sorts
		try ensureUniqueSort(sorts: &sorts)
		try filter(cursor: cursor, sorts: sorts)
		sorts.forEach { (sort) in
			let _ = self.sort(sort.querySort)
		}
		return self
	}

	// Filter out results before or after the cursor, depending upon order
	@discardableResult
	public func filter(cursor: String?, sorts: [KeyPathSort<Result>]) throws -> QueryBuilder<Database, Result>{
			guard let cursor = cursor else {
				return self
			}
			guard let decodedCursor = cursor.fromBase64() else {
				throw Abort(.badRequest, reason: "Expected cursor to be a base64 encoded string, received \(cursor).")
			}

			let cursorParts = decodedCursor.split(separator: ",")
			guard cursorParts.count == sorts.count else{
				throw Abort(.badRequest, reason: "That cursor does not does not match the sorts set for this query.")
			}
			var orderedCursorParts: [CursorPart] = []
			for cursorPart in cursorParts{
				let cursorSplit = cursorPart.split(separator: ":")

				guard 1...2 ~= cursorSplit.count   else { //1 == nil value
					throw Abort(.badRequest, reason: "Improperly formatted cursor part: \(cursorPart). Expected a key value pair delimited by ':'.")
				}
				let key: String = String(cursorSplit[0])

				let value: String? = cursorSplit.count == 2 ? String(cursorSplit[1]).fromBase64()! : nil
				orderedCursorParts.append(CursorPart(key: key, value: value))
			}

			debugPrint("Cursor decoded : \(orderedCursorParts.map({$0.key + " : " + ($0.value ?? "nil")}))")
			guard orderedCursorParts.count > 0 else {
				throw Abort(.badRequest, reason: "This cursor has no parts.")
			}

			guard let tieBreakerCursorPart = orderedCursorParts.last, let tiebreakerSort: KeyPathSort<Result> = sorts.last, tieBreakerCursorPart.key == tiebreakerSort.propertyName else{
				throw Abort(.badRequest, reason: "Improperly formatted pagination query. Last cursor part does not match final sort.")
			}

			guard orderedCursorParts.count > 1 else{ //Must be a unique, single field sort. So, we only need to get the values greater than or equal to the cursor fields value.
				try filter(for: tiebreakerSort, startingAt: tieBreakerCursorPart)
				return self
			}

			guard orderedCursorParts.count > 2 else{//One nondistinct sort + one distinct tiebreaker sort
				let nonDistinctCursorPart = orderedCursorParts.first!
				let nonDistinctQueryField = sorts.first!.queryField
				try group(Database.queryFilterRelationOr) { (or) in
					or.group(Database.queryFilterRelationAnd){ (and) in
						and.filter(nonDistinctQueryField, Database.queryFilterMethodEqual, nonDistinctCursorPart.value)
						and.filter(tiebreakerSort.queryField, self.filterMethod(for: tiebreakerSort.direction), tieBreakerCursorPart.value)
					}
					try or.filter(for: sorts[0], startingAt: nonDistinctCursorPart, inclusive: false)
				}
				return self
			}

			//There could be n nondistinct sorts + 1 final tiebreaker sort.
			//We must account for tiebreaks on each nondistinct sort.
			try group(Database.queryFilterRelationOr) { (or) in
				var cursorPartStack = orderedCursorParts
				var sortStack = sorts
				while cursorPartStack.count > 0{
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
							and.filter(sortStack[i].queryField, Database.queryFilterMethodEqual, part.value)
						}
					}
				}
			}
			return self

	}

	public func filterMethod(for direction: KeyPathSortDirection<Result>, inclusive: Bool = true) -> Database.QueryFilterMethod{
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
	public func filter(for sort: KeyPathSort<Result>, startingAt cursor: CursorPart, inclusive: Bool = true) throws -> QueryBuilder<Database, Result>{
		let key = cursor.key
		let field = sort.queryField
		let direction = sort.direction
		print("key: \(key)")
		print("field: \(field)")
		print("direction: \(direction)")
		print("inclusive: \(inclusive)")
		print("value: \(cursor.value)")
		guard let value = cursor.value else{
			switch (inclusive, direction){
			case (false, .ascending):
				filter(field, Database.queryFilterMethodNotEqual, cursor.value) //Include values that are not null
			default: break //Do nothing, nulls are naturally handled by the sort
			}
			return self
		}

		let tiebreakerMethod = filterMethod(for: direction)
		switch(direction){
			case .ascending:
				filter(field, tiebreakerMethod, value)
			case .descending:
				let idKey: String = Result.idKey.propertyName
				if key == idKey {
					filter(field, tiebreakerMethod, value)
				}
				else{
					let nilValue: String? = nil
					group(Database.queryFilterRelationOr){ (or) in //Handle nullability, sort nulls to be last
						or.filter(field, tiebreakerMethod, value)
						or.filter(field, Database.queryFilterMethodEqual, nilValue)
					}
				}
		}
		return self
	}
	public func ensureUniqueSort(sorts: inout [KeyPathSort<Result>]) throws {
		if sorts.count == 0 {
			sorts.append(contentsOf: Result.defaultPageSorts)
		}
		if sorts.count == 0 || sorts.last?.propertyName != Result.idKey.propertyName{
			//Use id for tiebreakers on nonunique sorts //TODO: Check schema for uniqueness instead of always applying id as tiebreaker
			sorts.append(Result.idKey.ascendingSort)
		}
	}

	public func cursorPart(forParameter name: String, withValue value: Any) throws -> String{
		var value = value
		switch value{
		case let optional as Optional<Any>:
			guard let unwrapped = optional.wrapped else{
				return "\(name):,"
			}
			value = unwrapped //Don't want Optional string description to get encoded
			fallthrough
		default:
			switch value{
			case let date as Date:
				value = date.timeIntervalSince1970 as Any
				fallthrough
			default:
				let stringValue = "\(value)".toBase64()
				return "\(name):\(stringValue),"
			}
		}
	}

	private func defaultCursorBuilder(_ sorts: [KeyPathSort<Result>]) -> CursorBuilder<Result>{
		let cursorBuilder: (Result) throws -> String = { (model: Result) in
			var cursor: String = ""
			for sort in sorts{
				let value = model[keyPath: sort.keyPath]
				cursor += try self.cursorPart(forParameter: sort.propertyName, withValue: value)
			}
			cursor = String(cursor.dropLast())
			return cursor
		}
		return cursorBuilder
	}


}
