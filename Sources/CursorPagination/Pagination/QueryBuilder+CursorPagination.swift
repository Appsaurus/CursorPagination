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
import CodableExtensions
import RuntimeExtensions
public typealias CursorBuilder<E: CursorPaginatable> = (E) throws -> String

//MARK: Main public API
extension QueryBuilder where Result: CursorPaginatable, Result.Database == Database {
	
	public func paginate(request: Request,
						 sorts: [CursorSort<Result>] = []) throws -> Future<CursorPage<Result>> {
		let params = try request.query.decode(CursorPaginationParameters.self)
		return try paginate(cursor: params.cursor, limit: params.limit, sorts: sorts)
	}

	/// Paginates a query on the given sorts using opqaue cursors. More
	///
	/// - Parameters:
	///   - cursor: A cursor marking the start of the next page of results. If none is supplied, it is assumed that the query should start from the begining of the results, or the first page.
	///   - limit: The page limit. Max number of items to return in one page.
	///   - sorts: The Sorts used to order the queries results. If there is only one sort, it must have uniquely indexable value. If the last sort in the array does not sort on a uniquely indexable field, then an additional sort will be applied. It will attempt to use the Result's default sort. If the models default sort is not uniquely indexable, it will use createdDate (if Timestampable) or the model ids to break ties.
	/// - Returns: A CursorPage<E> which contains the next page of results and a cursor for the next page if there are more results.
	public func paginate(cursor: String?,
						 limit: Int? = nil,
						 sorts: [CursorSort<Result>]) throws -> Future<CursorPage<Result>> {
		var sorts = sorts
		try ensureUniqueSort(sorts: &sorts)
		return try paginate(cursor: cursor, cursorBuilder: defaultCursorBuilder(sorts), limit: limit, sorts: sorts)
	}

	public func paginate(cursor: String?,
						 cursorBuilder: @escaping CursorBuilder<Result>,
						 limit: Int? = nil,
						 sorts: [CursorSort<Result>] = []) throws -> Future<CursorPage<Result>> {
		var sorts = sorts
		var limit = limit ?? Result.defaultPageSize
		if let max = Result.maxPageSize, limit > max{
			limit = max
		}
		try ensureUniqueSort(sorts: &sorts)
		let query = try sortedForPagination(cursor: cursor, sorts: sorts)
		
		let copy = self.query
		let total: Future<Int> = self.count()
		self.query = copy
		
		let data: Future<[Result]> = query.range(...limit).all()
		return map(to: CursorPage<Result>.self, data, total) { data, total in
			
			var data = data
			var nextPageCursor: String? = nil
			if data.count == limit + 1, let nextFirstItem: Result = data.last {
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

}

//MARK: Dynamic Paging
extension QueryBuilder where Result: CursorPaginatable, Result.Database == Database {
	//	Same as paginate(request:) but uses a dynamic sort determined on the client side by query parameters.
	//  NOTE: This requires some runtime reflection which you may not want to use in production until Swift ABI is stable. For now, useful
	//	for things that are not mission critical, like admin searching functionality.
	public func paginate(dynamicRequest: Request) throws -> Future<CursorPage<Result>> {
		let params = try dynamicRequest.query.decode(DynamicCursorPaginationParameters<Result>.self)
//        debugPrint("Params \(params)")
		return try paginate(cursor: params.cursor, limit: params.limit, sorts: try params.cursorSorts())

	}

}

//MARK: Implementation
extension QueryBuilder where Result: CursorPaginatable, Result.Database == Database {
	
	public func sortedForPagination(cursor: String?,
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
		guard let cursor = cursor else { return self }
		
		let cursorQueryBuilder = try CursorQueryBuilder<Result>(cursor: cursor, sorts: sorts)
		let filterBuilders = cursorQueryBuilder.filterBuilders

		//Must be a unique, single field sort. So, we only need to get the values greater than or equal to the cursor fields value.
		guard filterBuilders.count > 1 else{
			filter(filterBuilders[0])
			return self
		}

		//There could be 1...n nondistinct sorts + 1 distinct sort.
		//We must account for tiebreaks on each nondistinct sort.
		group(.or) { (or) in
			var filterPartStack = filterBuilders //Copy filter builders to a stack
			while filterPartStack.count > 2{
				or.group(.and){ (and) in
					let lastIndex = filterPartStack.count - 1
					for i in 0...lastIndex{
						let filter = filterPartStack[i]
						guard i == lastIndex else{
                            and.filter(filter, .equal)
							continue
						}
                        and.filter(filter, inclusive: sorts.count == filterPartStack.count)
                        filterPartStack.removeLast()
					}
				}
			}
			or.filterForTiebreaker(nonDistinctBuilder: filterPartStack[0], distinctBuilder: filterPartStack[1], totalSorts: sorts.count)

		}
		return self
		
	}
	
	
	@discardableResult
    public func filterForTiebreaker(nonDistinctBuilder: CursorFilterBuilder<Result>, distinctBuilder: CursorFilterBuilder<Result>, totalSorts: Int) -> QueryBuilder<Database, Result>{

		//Required value, don't need to account for nils
		guard nonDistinctBuilder.sort.fieldIsOptional else{
			group(.or) { (or) in
				or.group(.and){ (and) in
					and.filter(nonDistinctBuilder, .equal)
					and.filter(distinctBuilder, inclusive: totalSorts <= 2)
				}
				or.filter(nonDistinctBuilder, inclusive: false)
			}
			return self
		}

		//Handle nils

		let nilValue: String? = nil
		let direction = nonDistinctBuilder.sort.direction
		group(Database.queryFilterRelationOr) { (or) in
			switch nonDistinctBuilder.cursorPart.value{
			case .some(_):
				or.group(.and, closure: { (and) in
					and.filter(nonDistinctBuilder, .equal)
					and.filter(distinctBuilder, inclusive: true)
				})
				switch direction{
				case .ascending:
					or.filter(nonDistinctBuilder, .greaterThan)
				case .descending:
					or.filter(nonDistinctBuilder, .lessThan)
					or.filter(nonDistinctBuilder, .equal, nilValue)
				}
			case .none:
				switch direction{
				case .ascending:
					or.group(.and, closure: { (and) in
						and.filter(nonDistinctBuilder, .equal)
						and.filter(distinctBuilder)
					})
					or.filter(nonDistinctBuilder, .notEqual)
				case .descending:
					self.group(.and, closure: { (and) in
						and.filter(nonDistinctBuilder, .equal, nilValue)
						and.filter(distinctBuilder, inclusive: true)
					})
				}
			}
		}
		return self


	}

	
	@discardableResult
	fileprivate func filter<E: Encodable>(_ builder: CursorFilterBuilder<Result>,
										  _ method: CursorFilterMethod? = nil,
										  _ value: E,
										  inclusive: Bool = true) -> QueryBuilder<Database, Result>{
		let method = method ?? builder.filterMethod(inclusive: inclusive)
		filter(builder.sort.field, method, value)
		return self
	}

	@discardableResult
	fileprivate func filter(_ builder: CursorFilterBuilder<Result>,
							_ method: CursorFilterMethod? = nil,
							inclusive: Bool = true) -> QueryBuilder<Database, Result>{
		let method = method ?? builder.filterMethod(inclusive: inclusive)
		filter(builder.sort.field, method, builder.cursorPart.value)
		return self
	}

	@discardableResult
	fileprivate func filter<E: Encodable>(_ field: Database.QueryField,
										  _ method: CursorFilterMethod,
										  _ value: E) -> QueryBuilder<Database, Result>{
		filter(field, method.queryFilterMethod(modelType: Result.self), value)
		return self
	}

	public func ensureUniqueSort(sorts: inout [CursorSort<Result>]) throws {
		if sorts.count == 0 {
			sorts.append(contentsOf: Result.defaultPageSorts)
		}
		let property: FluentProperty = .keyPath(Result.idKey)
		if sorts.count == 0 || sorts.last?.propertyName != property.name{
			//Use id for tiebreakers on nonunique sorts //TODO: Check schema for uniqueness instead of always applying id as tiebreaker
			sorts.append(Result.idKey.ascendingSort)
		}
	}
	
	
	private func defaultCursorBuilder(_ sorts: [CursorSort<Result>]) throws -> CursorBuilder<Result>{
		let cursorBuilder: (Result) throws -> String = { (model: Result) in
			let cursorParts = try sorts.map({ (sort) -> CursorPart in
				let value: Any = sort.keyPath != nil ? model[keyPath: sort.keyPath!] : try RuntimeExtensions.get(sort.propertyName, from: model)
                let cursorPart = CursorPart(key: sort.propertyName, value: value, direction: sort.direction)
                return cursorPart
			})
            let encodedString = try cursorParts.encodeAsJSONString(encoder: JSONEncoder(.secondsSince1970))
			return encodedString
		}
		return cursorBuilder
	}
}

extension QueryBuilder where Result: CursorPaginatable, Result.Database == Database {
	@discardableResult
	func group(_ relation: CursorFilterRelation, closure: @escaping (QueryBuilder<Database, Result>) throws -> ()) rethrows -> Self{
		return try group(relation.queryFilterRelation(modelType: Result.self), closure: closure)
	}
}
