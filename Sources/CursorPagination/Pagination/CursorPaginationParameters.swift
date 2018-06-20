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
import Codability


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
