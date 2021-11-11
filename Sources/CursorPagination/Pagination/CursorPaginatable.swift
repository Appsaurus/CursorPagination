//
//  CursorPaginatable.swift
//  Appsaurus
//
//  Created by Brian Strobach on 5/3/18.
//

import FluentExtensions

public protocol CursorPaginatable: Model, Paginatable {
	static var defaultPageSorts: [CursorSort<Self>] { get }
}

extension CursorPaginatable {
	
	public static var defaultPageSorts: [CursorSort<Self>] {
        return []
//		return [createdAtKey?.descendingSort ?? idKey.ascendingSort]
	}
}

extension CursorPaginatable {
	

	public static func paginate(request: Request,
								sorts: [CursorSort<Self>]) throws -> Future<CursorPage<Self>> {
        return try query(on: request.db).paginate(request: request, sorts: sorts)
	}

	public static func paginate(request: Request,
								sorts: CursorSort<Self>...) throws -> Future<CursorPage<Self>> {
		
		return try paginate(request: request, sorts: sorts)
	}

	/// Paginates a query using opqaue cursors.
	///
	/// - Parameters:
	///   - cursor: A cursor marking the start of the next page of results. If none is supplied, it is assumed that the query should start from the begining of the results, or the first page.
	///   - limit: The page limit. Max number of items to return in one page. (optional - defaults to CursorPaginatable's defaultPageSize)
	///   - sorts: The Sorts used to order the queries results. If there is only one sort, it must have uniquely indexable value. If the last sort in the array does not sort on a uniquely indexable field, then an additional sort will be applied. It will attempt to use the Model's default sort. If the models default sort is not uniquely indexable, it will use createdDate (if Timestampable) or the model ids to break ties.
	/// - Returns: A CursorPage<E> which contains the next page of results and a cursor for the next page if there are more results.
	public static func paginate(on conn: Database,
								cursor: String?,
								limit: Int? = nil,
								sorts: [CursorSort<Self>]) throws -> Future<CursorPage<Self>> {
		return try query(on: conn).paginate(cursor: cursor, limit: limit, sorts: sorts)
	}

//	//	Same as paginate(request:) but uses a dynamic sort and optional cursor determined on the client side by query parameters.
//	//  NOTE: This requires some runtime reflection which you may not want to use in production until Swift ABI is stable. For now, useful
//	//	for things that are not mission critical, like admin searching functionality.
//	public static func paginate(dynamicdatabase: Database) throws -> Future<CursorPage<Self>> {
//		return try query(on: dynamicRequest).paginate(dynamicRequest: dynamicRequest)
//
//	}
}
