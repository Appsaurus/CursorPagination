//
//  CursorPart.swift
//  CursorPagination
//
//  Created by Brian Strobach on 6/20/18.
//

import Foundation
import Fluent
import Vapor
import RuntimeExtensions
import Codability
public struct CursorPart: Codable{
	public var field: String
	public var value: AnyCodable?
	public var direction: CursorSortDirection = .ascending
	public init(key: String, value: Any, direction: CursorSortDirection? = nil){
		self.field = key
		if let direction = direction { self.direction = direction }
		if let value = downcast(value, to: Optional<Any>.self){
			guard value != nil else{
				return
			}
			self.value = AnyCodable(value)
		}
		self.value = AnyCodable(value)
	}

	private func downcast<T>(_ value: Any, to _: T.Type) -> T? {
		return value as? T
	}

	public enum CodingKeys: CodingKey{
		case key
		case value
		case direction
	}
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(field, forKey: .key)
		try container.encodeIfPresent(value, forKey: .value)
	}
	public init(from decoder: Decoder) throws{
		let container = try decoder.container(keyedBy: CodingKeys.self)
		field = try container.decode(.key)
		value = try container.decodeIfPresent(.value)
		if let directon = try container.decodeIfPresent(CursorSortDirection.self, forKey: .direction){
			direction = directon
		}

	}





	//	public func decodedValue() throws -> Encodable?{
	//		guard let value = value else { return nil }
	//		var anyValue: Any = value as Any
	//		switch decodedType {
	//		case is Bool.Type:
	//			anyValue = value.bool! as Any
	//		default:
	//			break
	//		}
	//		return anyValue as? Encodable
	//	}
}
//public struct CursorPart{
//	public var key: String
//	public var decodedType: Any.Type
//	public var value: String?
//	public init(key: String, value: String?, as type: Any.Type) {
//        self.key = key
//		self.value = value
//		self.decodedType = type
//    }
//
//	public func decodedValue() throws -> Encodable?{
//		guard let value = value else { return nil }
//		var anyValue: Any = value as Any
//		switch decodedType {
//		case is Bool.Type:
//			anyValue = value.bool! as Any
//		default:
//			break
//		}
//		return anyValue as? Encodable
//	}
//
//	public func anyCodableValue() throws -> AnyCodable{
//		return AnyCodable(try decodedValue())
//	}
//}

func cast<E: Any>(_ object: Any, as: E.Type = E.self, orThrow error: Error) throws -> E {
	guard let castedValue = object as? E else{
		throw error
	}
	return castedValue
}
