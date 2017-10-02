//
//  FlickrClient.swift
//  Virtual Tourist
//
//  Created by Jason Wedepohl on 2017/09/29.
//  Copyright © 2017 Jason Wedepohl. All rights reserved.
//

import Foundation

class FlickrClient {
	
	//MARK: Singleton
	
	static let instance = FlickrClient()
	
	//MARK: Constants
	
	let apiScheme = "https"
	let apiHost = "api.flickr.com"
	let apiPath = "/services/rest"
	
	let searchBBoxHalfWidth = 1.0
	let searchBBoxHalfHeight = 1.0
	let searchLatRange = (-90.0, 90.0)
	let searchLonRange = (-180.0, 180.0)
	
	let maxSearchResultPage = 200
	
	struct ParameterKeys {
		static let method = "method"
		static let apiKey = "api_key"
		static let extras = "extras"
		static let format = "format"
		static let noJSONCallback = "nojsoncallback"
		static let safeSearch = "safe_search"
		static let boundingBox = "bbox"
		static let page = "page"
		static let perPage = "per_page"
	}
	
	struct ParameterValues {
		static let searchMethod = "flickr.photos.search"
		static let apiKey = "34791ec5bc09bbd40e9a8f67f42fbc1e"
		static let responseFormat = "json"
		static let disableJSONCallback = "1"
		static let mediumURL = "url_m"
		static let useSafeSearch = "1"
		static let perPage = "21"
	}
	
	let responseStatusOK = "ok"
	
	//MARK: Functions
	
	func getNearbyPhotos(_ pin: Pin, _ completion: @escaping (_ successful: Bool, _ photos: [Photo]?, _ displayError: String?) -> ()) {
		
		let methodParameters = [
			ParameterKeys.method: ParameterValues.searchMethod,
			ParameterKeys.apiKey: ParameterValues.apiKey,
			ParameterKeys.boundingBox: bboxString(pin.latitude, pin.longitude),
			ParameterKeys.safeSearch: ParameterValues.useSafeSearch,
			ParameterKeys.extras: ParameterValues.mediumURL,
			ParameterKeys.format: ParameterValues.responseFormat,
			ParameterKeys.noJSONCallback: ParameterValues.disableJSONCallback,
			ParameterKeys.perPage: ParameterValues.perPage
		]
		let request = getRequest(withParameters: methodParameters)
		
		let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
			
			let responseHandler = ResponseHandler(data, response, error)
			
			if let responseError = responseHandler.getResponseError() {
				completion(false, nil, responseError)
				return
			}
			
			guard let parsedResponse:SearchResponse = JSONParser.decode(data!) else {
				completion(false, nil, DisplayError.unexpected)
				return
			}
			
			if parsedResponse.stat != self.responseStatusOK {
				completion(false, nil, DisplayError.unexpected)
				return
			}
			
			let maxPage = min(parsedResponse.photos.pages, self.maxSearchResultPage)
			let randomPage = Int(arc4random_uniform(UInt32(maxPage))) + 1
			self.getNearbyPhotos(methodParameters, withPageNumber: randomPage, completion)
		}
		
		task.resume()
	}
	
	func downloadImage(_ urlString: String, _ completion: @escaping (_ successful: Bool, _ data: Data?, _ displayError: String?) -> ()) {
		let url = URL(string: urlString)
		
		let task = URLSession.shared.dataTask(with: url!) { data, response, error in
			let responseHandler = ResponseHandler(data, response, error)
			
			if let responseError = responseHandler.getResponseError() {
				completion(false, nil, responseError)
				return
			}
			
			completion(true, data!, nil)
		}
		
		task.resume()
	}
	
	private func getNearbyPhotos(_ methodParameters: [String: String],
	                             withPageNumber pageNumber: Int,
	                             _ completion: @escaping (_ successful: Bool, _ photos: [Photo]?, _ displayError: String?) -> ()) {
		
		var methodParametersWithPageNumber = methodParameters
		methodParametersWithPageNumber[ParameterKeys.page] = String(pageNumber)
		
		var request = getRequest(withParameters: methodParametersWithPageNumber)
		request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
		
		let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
			
			let responseHandler = ResponseHandler(data, response, error)
			
			if let responseError = responseHandler.getResponseError() {
				completion(false, nil, responseError)
				return
			}
			
			guard let parsedResponse:SearchResponse = JSONParser.decode(data!) else {
				completion(false, nil, DisplayError.unexpected)
				return
			}
			
			if parsedResponse.stat != self.responseStatusOK {
				completion(false, nil, DisplayError.unexpected)
				return
			}
			
			let photos = parsedResponse.photos.photo.map { Photo($0.url_m) }
			
			completion(true, photos, nil)
		}
		
		task.resume()
	}
	
	private func getRequest(withParameters parameters: [String:String]) -> URLRequest {
		
		var components = URLComponents()
		components.scheme = apiScheme
		components.host = apiHost
		components.path = apiPath
		components.queryItems = [URLQueryItem]()
		
		for (key, value) in parameters {
			let queryItem = URLQueryItem(name: key, value: "\(value)")
			components.queryItems!.append(queryItem)
		}
		
		return URLRequest(url: components.url!)
	}
	
	private func bboxString(_ latitude: Double, _ longitude: Double) -> String {
		let minimumLon = max(longitude - searchBBoxHalfWidth, searchLonRange.0)
		let minimumLat = max(latitude - searchBBoxHalfHeight, searchLatRange.0)
		let maximumLon = min(longitude + searchBBoxHalfWidth, searchLonRange.1)
		let maximumLat = min(latitude + searchBBoxHalfHeight, searchLatRange.1)
		return "\(minimumLon),\(minimumLat),\(maximumLon),\(maximumLat)"
	}
	
	//MARK: Response struct
	
	private struct SearchResponse : Codable {
		let photos: PhotosResponse
		let stat: String
	}
	
	private struct PhotosResponse: Codable {
		let page: Int
		let pages: Int
		let perpage: Int
		let total: String
		let photo: [PhotoResponse]
	}
	
	private struct PhotoResponse: Codable {
		let id: String
		let owner: String
		let secret: String
		let server: String
		let farm: Int
		let title: String
		let ispublic: Int
		let isfriend: Int
		let isfamily: Int
		let url_m: String
		let height_m: String
		let width_m: String
	}
}
