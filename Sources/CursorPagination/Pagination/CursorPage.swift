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
		return fluentProperty.name
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
extension FluentProperty{
	public var name: String{
		return path.joined(separator: ".")
	}
}
public struct KeyPathSort<M: CursorPaginatable>{
	public let keyPath:  PartialKeyPath<M>
	public let direction: KeyPathSortDirection<M>
	public var fluentProperty: FluentProperty

	public var propertyName: String{
		return fluentProperty.name
	}

	public var querySort: M.Database.QuerySort{
		return M.Database.querySort(queryField, direction.querySortDirection)
	}

	public var queryField: M.Database.QueryField{
		return M.Database.queryField(fluentProperty)
	}

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

////Workaround for swift's lack of covariance and contravariance on Optional type
////Allows for check like '<type> is OptionalProtocol' or 'isOptional(instance)
fileprivate protocol OptionalProtocol {}
extension Optional : OptionalProtocol {}

