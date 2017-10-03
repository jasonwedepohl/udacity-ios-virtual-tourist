//
//  Photo+CoreDataClass.swift
//  Virtual Tourist
//
//  Created by Jason Wedepohl on 2017/10/02.
//  Copyright © 2017 Jason Wedepohl. All rights reserved.
//
//

import Foundation
import CoreData

@objc(Photo)
public class Photo: NSManagedObject {
	private static let entityName = "Photo"
	private static let urlSortKey = "url"
	
	convenience init(_ url: String, _ pin: Pin, _ context: NSManagedObjectContext) {
		if let entityDescription = NSEntityDescription.entity(forEntityName: Photo.entityName, in: context) {
			self.init(entity: entityDescription, insertInto: context)
			self.url = url
			self.pin = pin
		} else {
			fatalError("Unable to initialise object.")
		}
	}
	
	static func getFetchRequest(forPin pin: Pin) -> NSFetchRequest<NSFetchRequestResult> {
		let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: Photo.entityName)
		let sortByUrlDescriptor = NSSortDescriptor(key: urlSortKey, ascending: true)
		fetchRequest.sortDescriptors = [sortByUrlDescriptor]
		fetchRequest.predicate = NSPredicate(format: "pin == %@", pin)
		return fetchRequest
	}
}
