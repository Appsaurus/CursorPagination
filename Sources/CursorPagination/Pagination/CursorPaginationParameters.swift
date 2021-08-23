//
//  Paginator.swift
//  Servasaurus
//
//  Created by Brian Strobach on 12/27/17.
//

import Foundation
import Fluent
import Vapor
import Codability

public struct CursorPaginationParameters: Content{
	public let cursor: String?
	public let limit: Int?
}

public struct DynamicCursorPaginationParameters<M: CursorPaginatable>: Content{
	public let cursor: String?
	public let limit: Int?
	public let fields: [String]
	public let directions: [String]

	public enum CodingKeys: String, CodingKey{
		case cursor
		case limit
		case fields = "sort"
		case directions = "order"
	}
	public func cursorSorts() throws -> [CursorSort<M>] {
		var sorts: [CursorSort<M>] = []
		for (index, field) in fields.enumerated(){
			sorts.append(try CursorSort<M>(direction: directions[index], propertyName: field))
		}
		return sorts
	}
}
