//
//  CursorSort.swift
//  CursorPagination
//
//  Created by Brian Strobach on 6/20/18.
//

import FluentExtensions


public enum CursorSortDirection: String, ExpressibleByStringLiteral, Codable{

    case ascending, descending

    public init(stringLiteral value: String) {
        self = CursorSortDirection.init(rawValue: value)!
    }

    public func querySortDirection() -> DatabaseQuery.Sort.Direction{
        switch self{
        case .ascending:
            return .ascending
        case .descending:
            return .descending
        }
    }
}
extension KeyPath where Root: Model, Value: QueryableProperty, Value.Model == Root {
    var fieldKeys: [FieldKey] {
        Root.path(for: self)
    }
}

extension String {
    var fieldKeys: [FieldKey] {
        [FieldKey(extendedGraphemeClusterLiteral: self)]
    }
}

public struct CursorSort<M: CursorPaginatable>{
//    public enum Property<M: Model, P: QueryableProperty> where P.Model == M {
//        case keyPath(KeyPath<M, P>)
//        case propertyName(String)
//
//        var fieldKey: [FieldKey] {
//            switch self {
//            case .keyPath(let keyPath):
//                return keyPath.fieldKeys
//            case .propertyName(let propertyName):
//                return propertyName.fieldKeys
//            }
//        }
//    }
//
//
//    var property: Property
    public var keyPath:  PartialKeyPath<M>?
    public var fieldKeys: [FieldKey]
	public let direction: CursorSortDirection

    public var field: DatabaseQuery.Field {
        return DatabaseQuery.Field.path(fieldKeys, schema: M.schema)
    }

	public var sort: DatabaseQuery.Sort{
        return DatabaseQuery.Sort.sort(field, direction.querySortDirection())
	}

    var propertyName: String {
        return fieldKeys.map({$0.description}).joined(separator: ".")
    }

//	public var field: DatabaseQuery.Field {
//        return DatabaseQuery.Field.path(fieldKeys, schema: M.schema)
//	}

//    public var sortDirection: DatabaseQuery.Sort.Direction{
//		return direction.querySortDirection(modelType: M.self)
//	}

	public var fieldIsOptional: Bool{
        return false
//		return fluentProperty.anyValue is OptionalProtocol.Type
	}

    public init<P: QueryableProperty>(_ keyPath: KeyPath<M, P>, _ direction: QuerySortDirection = .ascending) where P.Model == M{
        self.keyPath = keyPath
        self.fieldKeys = keyPath.fieldKeys
		self.direction = direction
//        self.fieldKeys = T.fieldKey
//		self.fluentProperty = .keyPath(keyPath)
	}

	public init(_ cursorPart: CursorPart) throws{
        try self.init(direction: cursorPart.direction, propertyName: cursorPart.field)
	}

	public init(direction: String, propertyName: String) throws {
        guard let cursorDirection = CursorSortDirection(rawValue: direction) else {
                throw Abort(.badRequest, reason: "Expected values of \'ascending\' or  \'descending\' for direction parameter, but received \(direction).")
        }

		try self.init(direction: cursorDirection, propertyName: propertyName)
	}
	public init(direction: CursorSortDirection, propertyName: String) throws {
//		guard let fluentProperty = try M.fluentProperty(named: propertyName) else {
//			throw Abort(.badRequest, reason: "Attempted to create a cursor sort is not part of this models schema.")
//		}
		self.direction = direction
        self.fieldKeys = [FieldKey(stringLiteral: propertyName)]
//		self.fluentProperty = fluentProperty
	}

    public static func sort<M: Model, P: QueryableProperty>(_ keyPath: KeyPath<M, P>, _ direction: QuerySortDirection = .ascending) -> CursorSort<M> where P.Model == M {
		return CursorSort<M>(keyPath, direction)
	}

    public static func ascending<M: Model, P: QueryableProperty>(_ keyPath: KeyPath<M, P>) -> CursorSort<M> where P.Model == M {
    return sort(keyPath, .ascending)
	}

    public static func descending<M: Model, P: QueryableProperty>(_ keyPath: KeyPath<M, P>) -> CursorSort<M> where P.Model == M {
    return sort(keyPath, .descending)
	}
}



extension KeyPath where Root: CursorPaginatable, Value: QueryableProperty, Value.Model == Root {
	public var ascendingSort: CursorSort<Root> {
		return sort(.ascending)
	}

	public var descendingSort: CursorSort<Root> {
		return sort(.descending)
	}
	public func sort(_ direction: QuerySortDirection = .ascending) -> CursorSort<Root> {
		return CursorSort<Root>(self, direction)
	}
}


////Workaround for swift's lack of covariance and contravariance on Optional type
////Allows for check like '<type> is OptionalProtocol' or 'isOptional(instance)
fileprivate protocol OptionalProtocol {}
extension Optional : OptionalProtocol {}
