//
//  Pin.swift
//  Virtual Tourist
//
//  Created by Jason Wedepohl on 2017/09/28.
//  Copyright © 2017 Jason Wedepohl. All rights reserved.
//

import Foundation

struct Pin {
	let latitude: Double
	let longitude: Double
	let id: String
	
	init(_ latitude: Double, _ longitude: Double) {
		self.latitude = latitude
		self.longitude = longitude
		self.id = UUID().uuidString
	}
}
