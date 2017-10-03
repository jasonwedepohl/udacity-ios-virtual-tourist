//
//  JSONParser.swift
//  Virtual Tourist
//
//  Created by Jason Wedepohl on 2017/09/29.
//  Copyright © 2017 Jason Wedepohl. All rights reserved.
//

import Foundation

class JSONParser {
	static func decode<T : Decodable>(_ data: Data) -> T? {
		do {
			return try JSONDecoder().decode(T.self, from: data)
		}
		catch {
			print("Could not decode the given data to type \(T.self): \(error.localizedDescription)")
			return nil
		}
	}
}
