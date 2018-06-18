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


//extension Database{
//	static func queryField(_ property: String) -> Database.QueryField{
//		FluentProperty
//	}
//}
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
		var sortFields = sortFields
		try ensureUniqueKeyPathSort(sorts: &sortFields)
		let cursorBuilder: (Result) throws -> String = { (model: Result) in
			var cursor: String = ""
			for field in sortFields{
				let value = model[keyPath: field.keyPath]
				cursor += try self.cursorPart(forParameter: field.propertyName, withValue: value)
			}
			cursor = String(cursor.dropLast())
			return cursor
		}

//		let sorts: [Database.QuerySort] = sortFields.map({ $0.querySort })
		return try paginate(cursor: cursor, cursorBuilder: cursorBuilder, count: count, sorts: sortFields)
	}

	public func paginate(cursor: String?,
						 cursorBuilder: @escaping CursorBuilder<Result>,
						 count: Int = 20,
						 sorts: [KeyPathSort<Result>] = []) throws -> Future<CursorPage<Result>> {

		// Filter out results before or after the cursor, depending upon order
		cursorWork: if let cursor = cursor{
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
				break cursorWork
			}

			guard orderedCursorParts.count > 2 else{//One nondistinct sort + one distinct tiebreaker sort
				let nonDistinctCursorPart = orderedCursorParts.first!
				try group(Database.queryFilterRelationOr) { (or) in
					or.group(Database.queryFilterRelationAnd){ (and) in
						and.filter(nonDistinctCursorPart.key, Database.queryFilterMethodEqual, nonDistinctCursorPart.value)
						and.filter(tieBreakerCursorPart.key, self.filterTiebreakerType(for: tiebreakerSort.direction), tieBreakerCursorPart.value)
					}
					try or.filter(for: sorts[0], startingAt: nonDistinctCursorPart, inclusive: false)
				}
				break cursorWork
			}

			//There could be n nondistinct sorts + 1 final tiebreaker sort.
			//We must account for tiebreaks on each nondistinct sort.
			try group(Database.queryFilterRelationOr) { (or) in
				var cursorPartStack = orderedCursorParts
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
								continue
							}
							and.filter(part.key, Database.queryFilterMethodEqual, part.value)
						}
					}
				}
			}
		}

		//Must overwrite other sorts that could break our sort order.
		//Sorts must be set in order matching cursor.
		sorts.forEach { (sort) in
			let _ = self.sort(sort.querySort)
		}


		//Additionally fetch first item of next page to generate cursor
		let limitIncludingNextItem = count + 1

//		let total: Future<Int> = self.count()
		let total: Future<Int> = all().map(to: Int.self) { (results) -> Int in
			return results.count
		}

		//Fetch our data
		let data: Future<[Result]> = range(...limitIncludingNextItem).all()

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

	public func filterTiebreakerType(for direction: KeyPathSortDirection<Result>, inclusive: Bool = true) -> Database.QueryFilterMethod{
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
		let direction = sort.direction

		guard let value = cursor.value else{
			switch (inclusive, direction){
			case (false, .ascending):
				return filter(key, Database.queryFilterMethodNotEqual, cursor.value) //Include values that are not null
			default: return self //Do nothing, nulls are naturally handled by the sort
			}
		}

		let nilValue: String? = nil
		switch (inclusive, direction){
		case (true, .ascending):
			return filter(key, Database.queryFilterMethodGreaterThanOrEqual, value)
		case (false, .ascending):
			return filter(key, Database.queryFilterMethodGreaterThanOrEqual, value)
		case (true, .descending):
			let idKey: String = Result.idKey.propertyName
			if key == idKey {
				return filter(key, Database.queryFilterMethodLessThanOrEqual, value)
			}
			return group(Database.queryFilterRelationOr){ (or) in //Handle nullability, sort nulls to be last
				or.filter(key, Database.queryFilterMethodLessThanOrEqual, value)
				or.filter(key, Database.queryFilterMethodEqual, nilValue)
			}
		case (false, .descending):
			let idKey: String = Result.idKey.propertyName
			if key == idKey {
				return filter(key, Database.queryFilterMethodLessThan, value)
			}
			return group(Database.queryFilterRelationOr){ (or) in //Handle nullability, sort nulls to be last
				or.filter(key, Database.queryFilterMethodLessThan, value)
				or.filter(key, Database.queryFilterMethodEqual, nilValue)
			}
		}
	}
	public func ensureUniqueSort(sorts: inout [KeyPathSort<Result>]) throws {
		if sorts.count == 0 { sorts.append(contentsOf: Result.defaultPageSorts) }
		if sorts.count == 0 || sorts.last?.keyPath != Result.idKey{
			//Use id for tiebreakers on nonunique sorts //TODO: Check schema for uniqueness instead of always applying id as tiebreaker
			sorts.append(Result.idKey.ascendingSort)
		}
	}

//	public func ensureUniqueSortField(sorts: inout [AnyKeyPath]) {
//		//Use id for tiebreakers on nonunique sorts
//		//TODO: Check schema for uniqueness instead of always applying id as tiebreaker
//		if sorts.last != Result.idKey{
//			sorts.append(Result.idKey)
//		}
//	}

	public func ensureUniqueKeyPathSort(sorts: inout [KeyPathSort<Result>]) throws {
		//Use id for tiebreakers on nonunique sorts
		//TODO: Check schema for uniqueness instead of always applying id as tiebreaker
		if sorts.last?.keyPath != Result.idKey{
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


}

//MARK: Anycodable/Reflection implementation (uses dict representation and KVC to build cursor)
//extension QueryBuilder where Result: CursorPaginatable {
//
//	//WARN: Uses reflection to generate cursor
//	public func paginate(cursor: String?,
//						 count: Int = Result.defaultPageSize,
//						 sorts: [Database.QuerySort] = Result.defaultPageSorts) throws -> Future<CursorPage<Result>> {
//		var sorts: [Database.QuerySort] = sorts
//		try ensureUniqueSort(sorts: &sorts, modelType: Result.self)
//
//		let cursorBuilder: (Result) throws -> String = { (model: Result) in
//			var cursor: String = ""
//			let json: Dictionary<String, Any> = try .init(model)
//			for sort in sorts{
//				let fieldName = sort.field.name
//				let value = json[fieldName] as Any
//				cursor += try self.cursorPart(forParameter: fieldName, withValue: value)
//			}
//			cursor = String(cursor.dropLast())
//			return cursor
//		}
//
//		return try paginate(cursor: cursor, cursorBuilder: cursorBuilder, count: count, sorts: sorts)
//	}
//
//	public func paginate(for req: Request,
//						 cursorBuilder: @escaping CursorBuilder<Result>,
//						 sorts: [Database.QuerySort] = []) throws -> Future<CursorPage<Result>> {
//		let params = req.cursorPaginationParameters()
//
//		return try self.paginate(cursor: params?.cursor,
//								 cursorBuilder: cursorBuilder,
//								 count: params?.limit ?? Result.defaultPageSize,
//								 sorts: sorts)
//	}
//}

fileprivate extension QueryBuilder{
//	@discardableResult
//	fileprivate  func filter(_ field: String, _ method: Database.QueryFilterMethod, _ value: Database.QueryFilterValue?) -> Self {
	/// Applies a comparison filter to this query.
	@discardableResult
	fileprivate  func filter(_ field: String, _ method: Database.QueryFilterMethod, _ value: String?) -> Self {
		return self
//		let filter = QueryFilter<Result.Database>(
//			field: QueryField(name: field),
//			type: type,
//			value: value
//		)
//		return addFilter(.single(filter))
	}
}
