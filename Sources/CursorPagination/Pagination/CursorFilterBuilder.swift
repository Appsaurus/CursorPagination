//
//  CursorFilterBuilder.swift
//  CursorPagination
//
//  Created by Brian Strobach on 6/20/18.
//

import Foundation
import Fluent
import Vapor

public struct CursorFilterBuilder<M: CursorPaginatable>{
	public var sort: CursorSort<M>
	public var cursorPart: CursorPart
	public init(sort: CursorSort<M>, cursorPart: CursorPart) {
		self.sort = sort
		self.cursorPart = cursorPart
	}
}

public struct CursorQueryBuilder<M: CursorPaginatable>{
	public var filterBuilders: [CursorFilterBuilder<M>] = []
	public init(cursor: String, sorts: [CursorSort<M>]) throws {
		let orderedCursorParts: [CursorPart] = try cursor.toCursorParts()
		guard orderedCursorParts.count > 0 else {
			throw Abort(.badRequest, reason: "This cursor has no parts.")
		}
		
		guard orderedCursorParts.count == sorts.count else{
			throw Abort(.badRequest, reason: "That cursor does not does not match the sorts set for this query.")
		}
		debugPrint("Cursor decoded : \(orderedCursorParts.map({$0.field + " : " + ("\(String(describing: $0.value))")}))")
		for (index, part) in orderedCursorParts.enumerated(){
			filterBuilders.append(CursorFilterBuilder<M>(sort: sorts[index], cursorPart: part))
			guard part.field == sorts[index].propertyName else {
				throw Abort(.badRequest, reason: "Cursor part does not match sort.")
			}
		}
	}
}
