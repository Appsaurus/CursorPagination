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

public struct KeyPathSort<M: CursorPaginatable>{
	public let querySort: QuerySort
	public let keyPath:  PartialKeyPath<M>
	public init<T>(_ keyPath: KeyPath<M, T>, _ direction: QuerySortDirection = .ascending) throws{
		querySort = try QuerySort(
			field: keyPath.makeQueryField(),
			direction: direction
		)
		self.keyPath = keyPath
	}
	public static func sort<M: Model, T>(_ keyPath: KeyPath<M, T>, _ direction: QuerySortDirection = .ascending) throws -> KeyPathSort<M>{
		return try KeyPathSort<M>(keyPath, direction)
	}

	public static func ascending<M: Model, T>(_ keyPath: KeyPath<M, T>) throws -> KeyPathSort<M>{
		return try sort(keyPath, .ascending)
	}

	public static func descending<M: Model, T>(_ keyPath: KeyPath<M, T>) throws -> KeyPathSort<M>{
		return try sort(keyPath, .descending)
	}
}

extension KeyPath where Root: CursorPaginatable {
	public func ascendingSort() throws -> KeyPathSort<Root> {
		return try sort(.ascending)
	}

	public func descendingSort() throws -> KeyPathSort<Root> {
		return try sort(.descending)
	}
	public func sort(_ direction: QuerySortDirection = .ascending) throws -> KeyPathSort<Root> {
		return try KeyPathSort(self, direction)
	}
}

//public protocol CursorPaginationSortResolvable{
//	associatedtype M: CursorPaginatable
//	func toCursorPaginationSort() throws -> CursorPaginationSort<M>
//}
//
//extension CursorPaginationSortResolvable{
//	public static func descending<T>(_ keyPath: KeyPath<M, T>) throws -> CursorPaginationSort<M>{
//		return try keyPath.descendingSort()
//	}
//}
//
//extension KeyPath: CursorPaginationSortResolvable where Root: CursorPaginatable{
//	public typealias M = Root
//
//	public func toCursorPaginationSort() throws -> CursorPaginationSort<M> {
//		return try sort()
//	}
//}
//
//extension CursorPaginationSort: CursorPaginationSortResolvable{
//	public func toCursorPaginationSort() throws -> CursorPaginationSort<M> {
//		return self
//	}
//}
