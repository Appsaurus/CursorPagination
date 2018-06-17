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
	public let remaining: Int
}

public struct KeyPathSort<M: CursorPaginatable>{
	public let querySort: M.Database.QuerySort
	public let keyPath:  PartialKeyPath<M>
	public let fluentProperty: FluentProperty
	public var propertyName: String{
		return fluentProperty.path.joined(separator: "_")
	}
	public init<T>(_ keyPath: KeyPath<M, T>, _ direction: M.Database.QuerySortDirection = M.Database.querySortDirectionAscending) throws{

		self.querySort = M.Database.querySort(M.Database.queryField(.keyPath(keyPath)), direction)
		self.keyPath = keyPath
		self.fluentProperty = .keyPath(keyPath)
	}
	public static func sort<M: Model, T>(_ keyPath: KeyPath<M, T>, _ direction: M.Database.QuerySortDirection = M.Database.querySortDirectionAscending) throws -> KeyPathSort<M>{
		return try KeyPathSort<M>(keyPath, direction)
	}

	public static func ascending<M: Model, T>(_ keyPath: KeyPath<M, T>) throws -> KeyPathSort<M>{
		return try sort(keyPath, M.Database.querySortDirectionAscending)
	}

	public static func descending<M: Model, T>(_ keyPath: KeyPath<M, T>) throws -> KeyPathSort<M>{
		return try sort(keyPath, M.Database.querySortDirectionDescending)
	}
}

extension KeyPath where Root: CursorPaginatable {
	public func ascendingSort() throws -> KeyPathSort<Root> {
		return try sort(Root.Database.querySortDirectionAscending)
	}

	public func descendingSort() throws -> KeyPathSort<Root> {
		return try sort(Root.Database.querySortDirectionDescending)
	}
	public func sort(_ direction: Root.Database.QuerySortDirection = Root.Database.querySortDirectionAscending) throws -> KeyPathSort<Root> {
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
