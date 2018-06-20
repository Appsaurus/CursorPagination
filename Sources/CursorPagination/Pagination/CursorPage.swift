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

//	public func querySort(_ direction: Root.Database.QuerySortDirection = Root.Database.querySortDirectionAscending)-> Root.Database.QuerySort{
//		return Root.Database.querySort(queryField, direction)
//	}
//	public var fluentProperty: FluentProperty{
//		return .keyPath(self)
//	}

//	public var queryField: Root.Database.QueryField{
//		return Root.Database.queryField(fluentProperty)
//	}

//	public var propertyName: String{
//		return fluentProperty.name
//	}
}

extension FluentProperty{
	public var name: String{
		return path.joined(separator: ".")
	}
}
