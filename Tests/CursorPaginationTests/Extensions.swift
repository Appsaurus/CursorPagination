//
//  File.swift
//  
//
//  Created by Brian Strobach on 8/20/21.
//

import Fluent

public extension Model{
    static var idKey: FieldKey{
        return Self()._$id.key
    }
}
