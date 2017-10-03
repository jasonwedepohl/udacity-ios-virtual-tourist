//
//  ResponseHandler.swift
//  Virtual Tourist
//
//  Created by Jason Wedepohl on 2017/09/29.
//  Copyright © 2017 Jason Wedepohl. All rights reserved.
//

import Foundation

class ResponseHandler {
	
	let systemOfflineErrorMessage = "The Internet connection appears to be offline."
	
	let data: Data?
	let response: URLResponse?
	let error: Error?
	
	init(_ data: Data?, _ response: URLResponse?, _ error: Error?) {
		self.data = data
		self.response = response
		self.error = error
	}
	
	func getResponseError() -> String? {
		
		//check no error was returned
		if error != nil {
			print(error!.localizedDescription)
			if error!.localizedDescription == systemOfflineErrorMessage {
				return DisplayError.network
			}
			return DisplayError.unexpected
		}
		
		//get http response
		guard let httpResponse = response as? HTTPURLResponse else {
			print("Expected HTTPURLResponse but was \(type(of: response))")
			return DisplayError.unexpected
		}
		
		//check http response status code was 2xx
		guard httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 else {
			print("There was a problem with the request. Status code is \(httpResponse.statusCode)")
			return DisplayError.unexpected
		}
		
		//check data was returned
		if data == nil {
			print("No data was returned in the response.")
			return DisplayError.unexpected
		}
		
		return nil
	}
}
