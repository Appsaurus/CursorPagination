//
//  Extensions.swift
//  CursorPagination
//
//  Created by Brian Strobach on 6/27/18.
//

import Foundation
import Vapor
import Fluent

extension Reflectable{
	static func propertyNamed(_ name: String) throws -> ReflectedProperty? {
		return try reflectProperties().named(name)
	}

	static func hasProperty(named name: String) throws -> Bool{
		return try propertyNamed(name) != nil
	}

	static func fluentProperty(named name: String) throws -> FluentProperty?{
		guard let property = try propertyNamed(name) else { return nil }
		return FluentProperty.reflected(property, rootType: self)
	}
}

extension ReflectedProperty{
	var name: String{
		return path.last!
	}
	var fullPath: String{
		return path.joined(separator: ".")
	}
}

extension Array where Element == ReflectedProperty{
	func named(_ name: String) -> ReflectedProperty? {
		return first(where: {$0.name == name})
	}
}

extension FluentProperty{
	var name: String{
		return path.last!
	}
	var fullPath: String{
		return path.joined(separator: ".")
	}
}
