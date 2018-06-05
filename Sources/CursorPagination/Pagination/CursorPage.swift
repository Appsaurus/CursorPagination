//
//  CursorPage.swift
//  CursorPagination
//
//  Created by Brian Strobach on 5/18/18.
//

import Foundation
import Fluent
import Vapor

// Represents a page of results, offset by an id value
public struct CursorPage<E: CursorPaginatable>: Content {
	public let nextPageCursor: String?
	public let data: [E]
	public let size: Int
	public let total: Int
}

public struct CursorPaginationSort<M: Model>{
	public let querySort: QuerySort
	public let keyPath:  PartialKeyPath<M>
	public init<T>(_ field: KeyPath<M, T>, _ direction: QuerySortDirection = .ascending) throws{
		querySort = try QuerySort(
			field: field.makeQueryField(),
			direction: direction
		)
		keyPath = field
	}
	public static func sort<M: Model, T>(_ field: KeyPath<M, T>, _ direction: QuerySortDirection = .ascending) throws -> CursorPaginationSort<M>{
		return try CursorPaginationSort<M>(field, direction)
	}
}
