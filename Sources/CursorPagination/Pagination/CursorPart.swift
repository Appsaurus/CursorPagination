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

extension String {

    func substring(from left: String, to right: String) -> String? {
        if let match = range(of: "(?<=\(left))[^\(right)]+", options: .regularExpression) {
            return String(self[match])
        }
        return nil
    }
}
extension DatabaseQuery.Sort.Direction {
    public init(string: String) {
        switch string {
        case "ascending": self = .ascending
        case "descending": self = .descending
        default:
            if let value = string.substring(from: "custom(", to: ")") {
                self = .custom(value)
            }
            else {
                self = .custom(string)
            }
        }
    }
}
public typealias QuerySortDirection = CursorSortDirection

//extension DatabaseQuery.Sort.Direction: Codable {
//    public func encode(to encoder: Encoder) throws {
//        var container = encoder.singleValueContainer()
//        try container.encode(self.description)
//    }
//
//    public init(from decoder: Decoder) throws {
//        let container = try decoder.singleValueContainer()
//        let stringValue = try container.decode(String.self)
//        switch stringValue {
//        case "ascending"
//        }
//    }
//}
public struct CursorPart: Codable {
    public var field: String
    public var value: AnyCodable?
    public var direction: QuerySortDirection = .ascending
    public init(key: String, value: Any, direction: QuerySortDirection? = nil){
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
        if let directon = try container.decodeIfPresent(QuerySortDirection.self, forKey: .direction){
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
