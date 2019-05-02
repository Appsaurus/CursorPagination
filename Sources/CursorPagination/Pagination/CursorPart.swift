//
//  CursorPart.swift
//  CursorPagination
//
//  Created by Brian Strobach on 6/20/18.
//

import Foundation
import Fluent
import Vapor
import Codability
import CodableExtensions

public struct CursorPart: Codable {
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
		try container.encode(direction, forKey: .direction)
	}
	public init(from decoder: Decoder) throws{
		let container = try decoder.container(keyedBy: CodingKeys.self)
		field = try container.decode(.key)
		value = try container.decodeIfPresent(.value)
		if let directon = try container.decodeIfPresent(CursorSortDirection.self, forKey: .direction){
			direction = directon
		}

	}

}

public extension String{
    func toCursorParts(isBase64Encoded: Bool = true) throws -> [CursorPart]{
		guard let decodedCursor = isBase64Encoded ? fromBase64() : self else{
			throw Abort(.badRequest, reason: "Expected cursor to be a base64 encoded string, received \(self).")
		}
		let orderedCursorPartDictionaries: [AnyCodableDictionary] = try decodedCursor.deserializeJSONAsArrayOfAnyCodableDictionaries()
		return try orderedCursorPartDictionaries.map({try CursorPart.decode(fromJSON: try $0.encodeAsJSONData())})
	}
}
