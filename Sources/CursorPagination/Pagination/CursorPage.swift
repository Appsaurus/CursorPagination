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

//extension KeyPath where Root: CursorPaginatable{
//
//	public func keyPathSort(_ direction: Root.Database.QuerySortDirection = Root.Database.querySortDirectionAscending) -> KeyPathSort<Root>{
//		return KeyPathSort<Root>.sort(self, direction)
//	}
//}
extension KeyPath where Root: Model{

	public func querySort(_ direction: Root.Database.QuerySortDirection = Root.Database.querySortDirectionAscending)-> Root.Database.QuerySort{
		return Root.Database.querySort(queryField, direction)
	}
	public var fluentProperty: FluentProperty{
		return .keyPath(self)
	}

	public var queryField: Root.Database.QueryField{
		return Root.Database.queryField(fluentProperty)
	}

	public var propertyName: String{
		return fluentProperty.path.joined(separator: "_")
	}
}

public enum KeyPathSortDirection<M: CursorPaginatable>{
	case ascending, descending
	public var querySortDirection: M.Database.QuerySortDirection{
		switch self{
		case .ascending:
			return M.Database.querySortDirectionAscending
		case .descending:
			return M.Database.querySortDirectionDescending
		}
	}
}
public struct KeyPathSort<M: CursorPaginatable>{
	public let keyPath:  PartialKeyPath<M>
	public let direction: KeyPathSortDirection<M>
	public var propertyName: String
	public var fluentProperty: FluentProperty
	public var querySort: M.Database.QuerySort
	public var queryField: M.Database.QueryField
	public var querySortDirection: M.Database.QuerySortDirection{
		return direction.querySortDirection
	}

	public var fieldIsOptional: Bool{
		return fluentProperty.valueType is OptionalProtocol.Type
	}

	public init<T>(_ keyPath: KeyPath<M, T>, _ direction: KeyPathSortDirection<M> = .ascending){
		self.keyPath = keyPath
		self.direction = direction
		self.fluentProperty = keyPath.fluentProperty
		self.propertyName = keyPath.propertyName
		self.querySort = M.Database.querySort(keyPath.queryField, direction.querySortDirection)
		self.queryField = keyPath.queryField
	}

	public static func sort<M: Model, T>(_ keyPath: KeyPath<M, T>, _ direction: KeyPathSortDirection<M> = .ascending) -> KeyPathSort<M>{
		return KeyPathSort<M>(keyPath, direction)
	}

	public static func ascending<M: Model, T>(_ keyPath: KeyPath<M, T>) -> KeyPathSort<M>{
		return sort(keyPath, .ascending)
	}

	public static func descending<M: Model, T>(_ keyPath: KeyPath<M, T>) -> KeyPathSort<M>{
		return sort(keyPath, .descending)
	}
}

extension KeyPath where Root: CursorPaginatable {
	public var ascendingSort: KeyPathSort<Root> {
		return sort(.ascending)
	}

	public var descendingSort: KeyPathSort<Root> {
		return sort(.descending)
	}
	public func sort(_ direction: KeyPathSortDirection<Root> = .ascending) -> KeyPathSort<Root> {
		return KeyPathSort(self, direction)
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

//Workaround for swift's lack of covariance and contravariance on Optional type
//Allows for check like '<type> is OptionalProtocol' or 'isOptional(instance)
public protocol OptionalProtocol {}

extension Optional : OptionalProtocol {}

public func isOptional(_ instance: Any) -> Bool {
	return instance is OptionalProtocol
}

