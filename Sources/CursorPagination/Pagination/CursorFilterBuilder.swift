//
//  CursorFilterBuilder.swift
//  CursorPagination
//
//  Created by Brian Strobach on 6/20/18.
//

import Foundation
import Fluent
import Vapor

public struct CursorFilter<M: CursorPaginatable>{
	public var sort: CursorSort<M>
	public var cursorPart: CursorPart
    public init(sort: CursorSort<M>, cursorPart: CursorPart) {
        self.sort = sort
        self.cursorPart = cursorPart
    }
}
