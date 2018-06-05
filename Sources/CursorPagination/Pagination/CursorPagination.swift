//
//  Paginator.swift
//  Servasaurus
//
//  Created by Brian Strobach on 12/27/17.
//

import Foundation
import Fluent
import Vapor
import RuntimeExtensions
public struct OffsetPaginationParameters: Codable{
	public let number: Int
	public let limit: Int
	public let total: Int
}

extension QuerySortDirection{
	public init?(string: String?){
		guard let string = string else {
			return nil
		}
		switch string.lowercased(){
		case "ascending":
			self = .ascending
		case "descending":
			self = .descending
		default: return nil
		}
	}
}
public struct CursorPaginationParameters{
	public let cursor: String?
	public let limit: Int?
}
extension Request{
	public func cursorPaginationParameters() -> CursorPaginationParameters? {
		let cursor: String? = try? query.get(at: "cursor")
		let limit: Int? = try? query.get(at: "limit")
		return CursorPaginationParameters(cursor: cursor, limit: limit)
	}
}

public typealias CursorBuilder<E: CursorPaginatable/* & QuerySupporting*/> = (E) throws -> String
public struct CursorPart{
	public var key: String
	public var value: String?
}

extension QueryBuilder where Model: CursorPaginatable {
	public func paginate(cursor: String?,
						 cursorBuilder: @escaping CursorBuilder<Model>,
						 count: Int = 20,
						 sorts: [QuerySort] = []) throws -> Future<CursorPage<Model>> {

		// Create the query and get a total count.
		let q: QueryBuilder<Model, Result> = self

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

			guard orderedCursorParts.count > 0 else {
				throw Abort(.badRequest, reason: "This cursor has no parts.")
			}

			guard let tieBreakerCursorPart = orderedCursorParts.last, let tiebreakerSort: QuerySort = sorts.last, tieBreakerCursorPart.key == tiebreakerSort.field.name else{
				throw Abort(.badRequest, reason: "Improperly formatted pagination query. Last cursor part does not match final sort.")
			}

			guard orderedCursorParts.count > 1 else{ //Must be a unique, single field sort. So, we only need to get the values greater than or equal to the cursor fields value.
				try filter(query: q, for: tiebreakerSort, startingAt: tieBreakerCursorPart)
				break cursorWork
			}

			guard orderedCursorParts.count > 2 else{//One nondistinct sort + one distinct tiebreaker sort
				let nonDistinctCursorPart = orderedCursorParts.first!
				try q.group(.or) { (q) in
					try q.group(.and){ (q) in
						q.filter(nonDistinctCursorPart.key, .equals, try .data(nonDistinctCursorPart.value))
						q.filter(tieBreakerCursorPart.key, self.filterTiebreakerType(for: tiebreakerSort.direction), try .data(tieBreakerCursorPart.value))
					}
					try self.filter(query: q, for: sorts[0], startingAt: nonDistinctCursorPart, inclusive: false)
				}
				break cursorWork
			}

			//There could be n nondistinct sorts + 1 final tiebreaker sort.
			//We must account for tiebreaks on each nondistinct sort.
			try q.group(.or) { (q) in
				var cursorPartStack = orderedCursorParts
				while cursorPartStack.count > 0{

					try q.group(.and){ (q) in
						let lastIndex = cursorPartStack.count - 1
						for i in 0...lastIndex{
							let part = cursorPartStack[i]
							guard i != lastIndex else{
								if sorts.count == cursorPartStack.count{
									try self.filter(query: q, for: sorts[i], startingAt: part)
								}
								else{
									try self.filter(query: q, for: sorts[i], startingAt: part, inclusive: false)
								}
								cursorPartStack.removeLast()
								continue
							}
							q.filter(part.key, .equals, try .data(part.value))
						}
					}
				}
			}
		}

		//Must overwrite other sorts that could break our sort order.
		//Sorts must be set in order matching cursor.
		q.query.sorts = sorts

		//Additionally fetch first item of next page to generate cursor
		let limitIncludingNextItem = count + 1

		//Fetch our data
		let data: Future<[Model]> = q.range(...limitIncludingNextItem).all() as! Future<[Model]>

		let total: Future<Int> = q.count()

		return map(to: CursorPage<Model>.self, data, total) { data, total in

			var data = data
			var nextPageCursor: String? = nil
			if data.count == limitIncludingNextItem, let nextFirstItem: Model = data.last{
				nextPageCursor = "\(try cursorBuilder(nextFirstItem).toBase64())"
				//Don't actually want to return this value yet, just getting its data to build the next cursor
				data.remove(at: data.count - 1)
			}

			return CursorPage(
				nextPageCursor: nextPageCursor,
				data: data,
				size: count,
				total: total
			)
		}


	}


	public func filterTiebreakerType<E>(for direction: QuerySortDirection, inclusive: Bool = true) -> QueryFilterType<E>{
		switch (inclusive, direction){
		case (true, .ascending):
			return .greaterThanOrEquals
		case (false, .ascending):
			return .greaterThan
		case (true, .descending):
			return .lessThanOrEquals
		case (false, .descending):
			return .lessThan
		}
	}



	@discardableResult
	public func filter<E, R>(query: QueryBuilder<E, R>, for sort: QuerySort, startingAt cursor: CursorPart, inclusive: Bool = true) throws -> QueryBuilder<E, R>{
		let key = cursor.key
		let direction = sort.direction

		guard let value = cursor.value else{
			switch (inclusive, direction){
			case (false, .ascending):
				return query.filter(key, .notEquals, try .data(cursor.value)) //Include values that are not null
			default: return query //Do nothing, nulls are naturally handled by the sort
			}
		}

		let nilValue: String? = nil
		switch (inclusive, direction){
		case (true, .ascending):
			return query.filter(key, .greaterThanOrEquals, try .data(value))
		case (false, .ascending):
			return query.filter(key, .greaterThan, try .data(value))
		case (true, .descending):
			if key == "id" { //TODO: Find a non-stringy way to do this
				return query.filter(key, .lessThanOrEquals, try .data(value))
			}
			return try query.group(.or){ (query) in //Handle nullability, sort nulls to be last
				query.filter(key, .lessThanOrEquals, try .data(value))
				query.filter(key, .equals, try .data(nilValue))
			}
		case (false, .descending):
			if key == "id" { //TODO: Find a non-stringy way to do this
				return query.filter(key, .lessThan, try .data(value))
			}
			return try query.group(.or){ (query) in //Handle nullability, sort nulls to be last
				query.filter(key, .lessThan, try .data(value))
				query.filter(key, .equals, try .data(nilValue))
			}
		}
	}
	public func ensureUniqueSort<E: CursorPaginatable>(sorts: inout [QuerySort], modelType: E.Type) {
		if sorts.count == 0 { sorts.append(contentsOf: modelType.defaultPageSorts) }
		let idKey: String = "id"
		//			let idKey: String = modelType.idKey
		if sorts.count == 0 || sorts.last!.field.name != idKey{
			sorts.append(QuerySort(field: QueryField(name: idKey), direction: .ascending)) //Use id for tiebreakers on nonunique sorts //TODO: Check schema for uniqueness instead of always applying id as tiebreaker
		}
	}

	public func ensureUniqueSortField(sorts: inout [AnyKeyPath]) {
		//Use id for tiebreakers on nonunique sorts
		//TODO: Check schema for uniqueness instead of always applying id as tiebreaker
		if sorts.last != Model.idKey{
			sorts.append(Model.idKey)
		}
	}

	public func ensureUniquePaginationSort(sorts: inout [CursorPaginationSort<Model>]) throws {
		//Use id for tiebreakers on nonunique sorts
		//TODO: Check schema for uniqueness instead of always applying id as tiebreaker
		if sorts.last?.keyPath != Model.idKey{
			sorts.append(try .sort(Model.idKey))
		}
	}


	/// Paginates a query on the given sorts using opqaue cursors. More
	///
	/// - Parameters:
	///   - cursor: A cursor marking the start of the next page of results. If none is supplied, it is assumed that the query should start from the begining of the results, or the first page.
	///   - count: The page limit. Max number of items to return in one page.
	///   - sorts: The Sorts used to order the queries results. If there is only one sort, it must have uniquely indexable value. If the last sort in the array does not sort on a uniquely indexable field, then an additional sort will be applied. It will attempt to use the Model's default sort. If the models default sort is not uniquely indexable, it will use createdDate (if Timestampable) or the model ids to break ties.
	/// - Returns: A CursorPage<E> which contains the next page of results and a cursor for the next page if there are more results.
	public func paginate(cursor: String?,
						 count: Int = Model.defaultPageSize,
						 sortFields: [CursorPaginationSort<Model>]) throws -> Future<CursorPage<Model>> {
		var sortFields = sortFields
		try ensureUniquePaginationSort(sorts: &sortFields)
		let cursorBuilder: (Model) throws -> String = { (model: Model) in
			var cursor: String = ""
			for field in sortFields{
				let value = model[keyPath: field.keyPath]
				let fieldName = field.querySort.field.name
				cursor += self.cursorPart(forParameter: fieldName, withValue: value)
			}
			cursor = String(cursor.dropLast())
			return cursor
		}

		let sorts: [QuerySort] = sortFields.map({ $0.querySort })
		return try paginate(cursor: cursor, cursorBuilder: cursorBuilder, count: count, sorts: sorts)
	}

	public func cursorPart(forParameter name: String, withValue value: Any) -> String{
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

	//WARN: Uses reflection to generate cursor
	public func paginate(cursor: String?,
						 count: Int = Model.defaultPageSize,
						 sorts: [QuerySort] = Model.defaultPageSorts) throws -> Future<CursorPage<Model>> {
		var sorts: [QuerySort] = sorts
		ensureUniqueSort(sorts: &sorts, modelType: Model.self)

		let cursorBuilder: (Model) throws -> String = { (model: Model) in
			var cursor: String = ""
			let json: Dictionary<String, Any> = try .init(model)
			for sort in sorts{
				let fieldName = sort.field.name
				let value = json[fieldName] as Any
				cursor += self.cursorPart(forParameter: fieldName, withValue: value)
			}
			cursor = String(cursor.dropLast())
			return cursor
		}

		return try paginate(cursor: cursor, cursorBuilder: cursorBuilder, count: count, sorts: sorts)
	}

	public func paginate(for req: Request,
						 cursorBuilder: @escaping CursorBuilder<Model>,
						 sorts: [QuerySort] = []) throws -> Future<CursorPage<Model>> {
		let params = req.cursorPaginationParameters()

		return try self.paginate(cursor: params?.cursor,
								 cursorBuilder: cursorBuilder,
								 count: params?.limit ?? Model.defaultPageSize,
								 sorts: sorts)
	}
}

extension QueryBuilder{

	/// Applies a comparison filter to this query.
	@discardableResult
	public func filter(_ field: String, _ type: QueryFilterType<Model.Database>, _ value: QueryFilterValue<Model.Database>) -> Self {
		let filter = QueryFilter<Model.Database>(
			field: QueryField(name: field),
			type: type,
			value: value
		)
		return addFilter(.single(filter))
	}
}






extension QuerySort{
	public init<Root: Model, Value, KP: KeyPath<Root, Value>>(_ keyPath: KP, _ direction: QuerySortDirection = .ascending) throws{
		self.init(field: try keyPath.makeQueryField(), direction: direction)
	}
}

extension KeyPath where Root: Model {
	public func ascending() throws -> QuerySort {
		return try sort(.ascending)
	}

	public func descending() throws -> QuerySort {
		return try sort(.descending)
	}
	public func sort(_ direction: QuerySortDirection = .ascending) throws -> QuerySort {
		return try QuerySort(self, direction)
	}
}
