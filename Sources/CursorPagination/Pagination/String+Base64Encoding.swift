//
//  String+Base64Encoding.swift
//  CursorPagination
//
//  Created by Brian Strobach on 5/18/18.
//

import Foundation

extension String {

	public func fromBase64() -> String? {
		guard let data = Data(base64Encoded: self) else {
			return nil
		}

		return String(data: data, encoding: .utf8)
	}

	public func toBase64() -> String {
		return Data(self.utf8).base64EncodedString()
	}
}
