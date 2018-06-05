//
//  CursorPaginatable.swift
//  Servasaurus
//
//  Created by Brian Strobach on 5/3/18.
//

import Foundation
import Fluent
import Vapor
import Pagination

public protocol CursorPaginatable: Pagination.Paginatable{}

extension CursorPaginatable{
	public static var defaultPageGroups: [QueryGroupBy] {
		return []
	}
	static public var defaultPageSorts: [QuerySort] {
		let field = (try? idKey.makeQueryField()) ?? QueryField(name: "id")
		return [QuerySort(field: field, direction: .ascending)]
	}
	static public var defaultPageSize: Int {
		return 20
	}
}

extension CursorPaginatable {

	/// Paginates a query using opqaue cursors.
	///
	/// - Parameters:
	///   - cursor: A cursor marking the start of the next page of results. If none is supplied, it is assumed that the query should start from the begining of the results, or the first page.
	///   - count: The page limit. Max number of items to return in one page.
	///   - sorts: The Sorts used to order the queries results. If there is only one sort, it must have uniquely indexable value. If the last sort in the array does not sort on a uniquely indexable field, then an additional sort will be applied. It will attempt to use the Model's default sort. If the models default sort is not uniquely indexable, it will use createdDate (if Timestampable) or the model ids to break ties.
	/// - Returns: A CursorPage<E> which contains the next page of results and a cursor for the next page if there are more results.
	public static func paginate(on conn: DatabaseConnectable,
								cursor: String?,
								count: Int = defaultPageSize,
								sortFields: [CursorPaginationSort<Self>]) throws -> Future<CursorPage<Self>> {
		return try query(on: conn).paginate(cursor: cursor, count: count, sortFields: sortFields)
	}

	/// Paginates a query on the given sorts using opqaue cursors. More
	///
	/// - Parameters:
	///   - cursor: A cursor marking the start of the next page of results. If none is supplied, it is assumed that the query should start from the begining of the results, or the first page.
	///   - count: The page limit. Max number of items to return in one page.
	///   - sorts: The Sorts used to order the queries results. If there is only one sort, it must have uniquely indexable value. If the last sort in the array does not sort on a uniquely indexable field, then an additional sort will be applied. It will attempt to use the Model's default sort. If the models default sort is not uniquely indexable, it will use createdDate (if Timestampable) or the model ids to break ties.
	/// - Returns: A CursorPage<E> which contains the next page of results and a cursor for the next page if there are more results.
	public static func paginate(on conn: DatabaseConnectable,
								cursor: String?,
								count: Int = defaultPageSize,
								sorts: [QuerySort] = defaultPageSorts) throws -> Future<CursorPage<Self>> {
		return try query(on: conn).paginate(cursor: cursor, count: count, sorts: sorts)

	}

	public static func paginate(request: Request,
								cursorBuilder: @escaping CursorBuilder<Self>,
								sorts: [QuerySort] = []) throws -> Future<CursorPage<Self>> {
		let params = request.cursorPaginationParameters()

		return try self.query(on: request).paginate(cursor: params?.cursor,
													cursorBuilder: cursorBuilder,
													count: params?.limit ?? Self.defaultPageSize,
													sorts: sorts)
	}

}


