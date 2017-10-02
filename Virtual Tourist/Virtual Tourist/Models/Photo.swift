//
//  Photo.swift
//  Virtual Tourist
//
//  Created by Jason Wedepohl on 2017/10/02.
//  Copyright © 2017 Jason Wedepohl. All rights reserved.
//

import Foundation

struct Photo {
	let url: String
	var imageData: Data?
	
	init(_ url: String) {
		self.url = url
	}
}
