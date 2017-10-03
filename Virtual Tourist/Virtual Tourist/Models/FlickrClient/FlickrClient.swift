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
		static let perPage = "21" //in this app, a collection view of max 3*7 photos needs to be filled
	}
	
	let responseStatusOK = "ok"
	
	//Flickr limits results per search to 4000, so need to constrain randomPage upper bound such that randomPage * itemsPerPage < 4000
	//itemsPerPage is 21 in this app
	let maxSearchResultPage:Int32 = 4000/21
	
	//MARK: Functions
	
	func getNearbyPhotos(_ pin: Pin, _ completion: @escaping (_ successful: Bool, _ displayError: String?) -> ()) {
		
		let methodParameters = getSearchRequestParameters(forPin: pin)
		let request = getRequest(withParameters: methodParameters)
		
		let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
			
			let responseHandler = ResponseHandler(data, response, error)
			
			if let responseError = responseHandler.getResponseError() {
				completion(false, responseError)
				return
			}
			
			guard let parsedResponse:SearchResponse = JSONParser.decode(data!) else {
				completion(false, DisplayError.unexpected)
				return
			}
			
			if parsedResponse.stat != self.responseStatusOK {
				completion(false, DisplayError.unexpected)
				return
			}
			
			//set search result stats on pin so they can be reused
			//pin was loaded in main context, so this change will be persisted to Core Data when app closes (in AppDelegate)
			pin.flickrPages = Int32(parsedResponse.photos.pages)
			pin.flickrTotalCount = Int32(parsedResponse.photos.total)!
			
			self.getRandomPageOfNearbyPhotos(pin, completion)
		}
		
		task.resume()
	}
	
	func getRandomPageOfNearbyPhotos(_ pin: Pin, _ completion: @escaping (_ successful: Bool, _ displayError: String?) -> ()) {
		
		let maxPage = min(pin.flickrPages, maxSearchResultPage)
		let randomPage = Int(arc4random_uniform(UInt32(maxPage))) + 1
		
		var methodParametersWithPageNumber = getSearchRequestParameters(forPin: pin)
		methodParametersWithPageNumber[ParameterKeys.page] = String(randomPage)
		
		var request = getRequest(withParameters: methodParametersWithPageNumber)
		request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
		
		let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
			
			let responseHandler = ResponseHandler(data, response, error)
			
			if let responseError = responseHandler.getResponseError() {
				completion(false, responseError)
				return
			}
			
			guard let parsedResponse:SearchResponse = JSONParser.decode(data!) else {
				completion(false, DisplayError.unexpected)
				return
			}
			
			if parsedResponse.stat != self.responseStatusOK {
				completion(false, DisplayError.unexpected)
				return
			}
			
			var photos = [Photo]()
			for photoResponse in parsedResponse.photos.photo {
				
				//sometimes for some reason url_m is missing from the photo
				if let url = photoResponse.url_m {
					
					//create photo in main context
					let photo = Photo(url, pin, CoreDataStack.instance.context)
					photos.append(photo)
				}
			}
			CoreDataStack.instance.save()
			
			//handle completion now so UI shows activity indicators for each photo to be downloaded
			completion(true, nil)
			
			//continue to download photos in background, FRC will handle updates
			for photo in photos {
				self.downloadPhoto(fromUrl: photo.url!) { (successful, imageData, displayError) in
					if successful {
						//set photo data to image data
						photo.data = imageData
						CoreDataStack.instance.save()
					} else {
						print("Could not download image: \(displayError!)")
					}
				}
			}
		}
		
		task.resume()
	}
	
	private func downloadPhoto(fromUrl urlString: String, _ completion: @escaping (_ successful: Bool, _ data: Data?, _ displayError: String?) -> ()) {
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
	
	private func getSearchRequestParameters(forPin pin: Pin) -> [String:String] {
		return [
			ParameterKeys.method: ParameterValues.searchMethod,
			ParameterKeys.apiKey: ParameterValues.apiKey,
			ParameterKeys.boundingBox: bboxString(pin.latitude, pin.longitude),
			ParameterKeys.safeSearch: ParameterValues.useSafeSearch,
			ParameterKeys.extras: ParameterValues.mediumURL,
			ParameterKeys.format: ParameterValues.responseFormat,
			ParameterKeys.noJSONCallback: ParameterValues.disableJSONCallback,
			ParameterKeys.perPage: ParameterValues.perPage
		]
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
		let url_m: String?
		let height_m: String?
		let width_m: String?
	}
}
