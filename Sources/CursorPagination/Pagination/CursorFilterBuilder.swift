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

	public func filterMethod(inclusive: Bool = true) -> CursorFilterMethod{
		switch (inclusive, sort.direction){
		case (true, .ascending):
			return .greaterThanOrEqual
		case (false, .ascending):
			return .greaterThan
		case (true, .descending):
			return .lessThanOrEqual
		case (false, .descending):
			return .lessThan
		}
	}
}


public enum CursorFilterMethod: String, ExpressibleByStringLiteral, Codable{

	case equal
	case notEqual
	case greaterThan
	case greaterThanOrEqual
	case lessThan
	case lessThanOrEqual

	public init(stringLiteral value: String) {
		self = CursorFilterMethod.init(rawValue: value)!
	}

	public func queryFilterMethod<M: CursorPaginatable>(modelType: M.Type = M.self) -> M.Database.QueryFilterMethod{
		switch self{
		case .equal:
			return M.Database.queryFilterMethodEqual
		case .notEqual:
			return M.Database.queryFilterMethodNotEqual
		case .greaterThan:
			return M.Database.queryFilterMethodGreaterThan
		case .greaterThanOrEqual:
			return M.Database.queryFilterMethodGreaterThanOrEqual
		case .lessThan:
			return M.Database.queryFilterMethodLessThan
		case .lessThanOrEqual:
			return M.Database.queryFilterMethodLessThanOrEqual
		}
	}
}
public struct CursorQueryBuilder<M: CursorPaginatable>{
	public var filterBuilders: [CursorFilterBuilder<M>] = []
	public init(cursor: String, sorts: [CursorSort<M>]) throws {
		let orderedCursorParts: [CursorPart] = try cursor.toCursorParts()
//        debugPrint("Cursor Parts: \(orderedCursorParts)")
		guard orderedCursorParts.count > 0 else {
			throw Abort(.badRequest, reason: "This cursor has no parts.")
		}
		
		guard orderedCursorParts.count == sorts.count else{
			throw Abort(.badRequest, reason: "That cursor does not does not match the sorts set for this query.")
		}
		
		for (index, part) in orderedCursorParts.enumerated(){
			filterBuilders.append(CursorFilterBuilder<M>(sort: sorts[index], cursorPart: part))
			guard part.field == sorts[index].propertyName else {
				throw Abort(.badRequest, reason: "Cursor part does not match sort.")
			}
		}
	}
}
