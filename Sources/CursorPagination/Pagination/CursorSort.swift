//
//  CursorSort.swift
//  CursorPagination
//
//  Created by Brian Strobach on 6/20/18.
//

import Foundation
import Fluent
import Vapor


extension ReflectedProperty{
	public var fullPath: String{
		return path.joined(separator: ".")
	}
}

extension FluentProperty{
	public var fullPath: String{
		return path.joined(separator: ".")
	}
}
extension Array where Element == ReflectedProperty{
	public func matching(name: String) -> ReflectedProperty? {
		return first(where: {$0.fullPath == name})
	}
}

extension Reflectable{
	public static func propertyNamed(_ name: String) throws -> ReflectedProperty? {
		return try reflectProperties().matching(name: name)
	}

	public static func hasProperty(named name: String) throws -> Bool{
		return try propertyNamed(name) != nil
	}

	public static func fluentProperty(named name: String) throws -> FluentProperty?{
		guard let property = try propertyNamed(name) else { return nil }
		return FluentProperty.reflected(property, rootType: self)
	}
}
public struct CursorSort<M: CursorPaginatable>{
	public var keyPath:  PartialKeyPath<M>?
	public let direction: CursorSortDirection
	public var fluentProperty: FluentProperty

	public var propertyName: String{
		return fluentProperty.fullPath
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

	public init(_ cursorPart: CursorPart) throws{
		try self.init(direction: cursorPart.direction, propertyName: cursorPart.field)
	}

	public init(direction: String, propertyName: String) throws {
		guard let cursorDirection = CursorSortDirection.init(rawValue: direction) else {
			throw Abort(.badRequest, reason: "Expected values of \'ascending\' or  \'descending\' for direction parameter, but received \(direction).")
		}
		try self.init(direction: cursorDirection, propertyName: propertyName)
	}
	public init(direction: CursorSortDirection, propertyName: String) throws {
		guard let fluentProperty = try M.fluentProperty(named: propertyName) else {
			throw Abort(.badRequest, reason: "Attempted to create a cursor sort is not part of this models schema.")
		}
		self.direction = direction
		self.fluentProperty = fluentProperty
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

public enum CursorSortDirection: String, ExpressibleByStringLiteral, Codable{

	case ascending, descending

	public init(stringLiteral value: String) {
		self = CursorSortDirection.init(rawValue: value)!
	}

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
