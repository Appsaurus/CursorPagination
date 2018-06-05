//
//  Paginator.swift
//  Servasaurus
//
//  Created by Brian Strobach on 12/27/17.
//

import Foundation
import Fluent
import Vapor
import RuntimeExtensions
public struct OffsetPaginationParameters: Codable{
	public let number: Int
	public let limit: Int
	public let total: Int
}

//extension QuerySortDirection{
//	public init?(string: String?){
//		guard let string = string else {
//			return nil
//		}
//		switch string.lowercased(){
//		case "ascending":
//			self = .ascending
//		case "descending":
//			self = .descending
//		default: return nil
//		}
//	}
//}
public struct CursorPaginationParameters{
	public let cursor: String?
	public let limit: Int?
}
extension Request{
	public func cursorPaginationParameters() -> CursorPaginationParameters? {
		let cursor: String? = try? query.get(at: "cursor")
		let limit: Int? = try? query.get(at: "limit")
		return CursorPaginationParameters(cursor: cursor, limit: limit)
	}
}

public typealias CursorBuilder<E: CursorPaginatable/* & QuerySupporting*/> = (E) throws -> String
public struct CursorPart{
	public var key: String
	public var value: String?
}

extension QuerySort{
	public init<Root: Model, Value, KP: KeyPath<Root, Value>>(_ keyPath: KP, _ direction: QuerySortDirection = .ascending) throws{
		self.init(field: try keyPath.makeQueryField(), direction: direction)
	}
}

extension KeyPath where Root: Model {
	public func ascending() throws -> QuerySort {
		return try sort(.ascending)
	}

	public func descending() throws -> QuerySort {
		return try sort(.descending)
	}
	public func sort(_ direction: QuerySortDirection = .ascending) throws -> QuerySort {
		return try QuerySort(self, direction)
	}
}
