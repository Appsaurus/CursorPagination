//
//  CursorSort.swift
//  CursorPagination
//
//  Created by Brian Strobach on 6/20/18.
//

import Foundation
import Fluent
import Vapor



public struct CursorSort<M: CursorPaginatable>{
	public let keyPath:  PartialKeyPath<M>
	public let direction: CursorSortDirection
	public var fluentProperty: FluentProperty

	public var propertyName: String{
		return fluentProperty.name
	}

	public var sort: M.Database.QuerySort{
		return M.Database.querySort(field, sortDirection)
	}

	public var field: M.Database.QueryField{
		return M.Database.queryField(fluentProperty)
	}

	public var sortDirection: M.Database.QuerySortDirection{
		return direction.querySortDirection(modelType: M.self)
	}

	public var fieldIsOptional: Bool{
		return fluentProperty.valueType is OptionalProtocol.Type
	}

	public init<T>(_ keyPath: KeyPath<M, T>, _ direction: CursorSortDirection = .ascending){
		self.keyPath = keyPath
		self.direction = direction
		self.fluentProperty = .keyPath(keyPath)
	}

	public static func sort<M: Model, T>(_ keyPath: KeyPath<M, T>, _ direction: CursorSortDirection = .ascending) -> CursorSort<M>{
		return CursorSort<M>(keyPath, direction)
	}

	public static func ascending<M: Model, T>(_ keyPath: KeyPath<M, T>) -> CursorSort<M>{
		return sort(keyPath, .ascending)
	}

	public static func descending<M: Model, T>(_ keyPath: KeyPath<M, T>) -> CursorSort<M>{
		return sort(keyPath, .descending)
	}
}

public enum CursorSortDirection: String, Codable{

	case ascending, descending
	public func querySortDirection<M: CursorPaginatable>(modelType: M.Type = M.self) -> M.Database.QuerySortDirection{
		switch self{
		case .ascending:
			return M.Database.querySortDirectionAscending
		case .descending:
			return M.Database.querySortDirectionDescending
		}
	}
}

extension KeyPath where Root: CursorPaginatable {
	public var ascendingSort: CursorSort<Root> {
		return sort(.ascending)
	}

	public var descendingSort: CursorSort<Root> {
		return sort(.descending)
	}
	public func sort(_ direction: CursorSortDirection = .ascending) -> CursorSort<Root> {
		return CursorSort(self, direction)
	}
}


////Workaround for swift's lack of covariance and contravariance on Optional type
////Allows for check like '<type> is OptionalProtocol' or 'isOptional(instance)
fileprivate protocol OptionalProtocol {}
extension Optional : OptionalProtocol {}
