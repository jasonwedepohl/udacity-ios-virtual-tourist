//
//  Pin+CoreDataClass.swift
//  Virtual Tourist
//
//  Created by Jason Wedepohl on 2017/10/02.
//  Copyright © 2017 Jason Wedepohl. All rights reserved.
//
//

import Foundation
import CoreData
import MapKit

@objc(Pin)
public class Pin: NSManagedObject, MKAnnotation {
	
	//MARK: Constants
	
	private static let entityName = "Pin"
	
	//can't use optional Int32 in Core Data so will use -1 to mean "nil"
	static let nilValueForInt:Int32 = -1
	
	//MARK: Properties
	
	//must be dynamic for location to be updated on map, see https://stackoverflow.com/questions/34475342/custom-mkannotation-not-moving-when-coordinate-set
	dynamic public var coordinate: CLLocationCoordinate2D {
		get {
			return CLLocationCoordinate2DMake(latitude, longitude)
		}
		set {
			latitude = newValue.latitude
			longitude = newValue.longitude
		}
	}
	
	var mustAnimatePinDrop = false
	
	//MARK: Init
	
	convenience init(_ coordinate: CLLocationCoordinate2D, _ context: NSManagedObjectContext) {
		if let entityDescription = NSEntityDescription.entity(forEntityName: Pin.entityName, in: context) {
			self.init(entity: entityDescription, insertInto: context)
			self.coordinate = coordinate
			self.id = UUID()
			self.flickrPages = Pin.nilValueForInt
			self.flickrTotalCount = Pin.nilValueForInt
			self.mustAnimatePinDrop = true
		} else {
			fatalError("Unable to initialise object.")
		}
	}
	
	static func fetchAll() -> [Pin] {
		let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: Pin.entityName)
		var items = [Pin]()
		do {
			//fetch pins from main context
			let results = try CoreDataStack.instance.context.fetch(fetchRequest)
			items = results as! [Pin]
		} catch {
			print("Could not load pins: \(error.localizedDescription)")
		}
		return items
	}
}
