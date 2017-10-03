//
//  Pin+CoreDataProperties.swift
//  Virtual Tourist
//
//  Created by Jason Wedepohl on 2017/10/03.
//  Copyright © 2017 Jason Wedepohl. All rights reserved.
//
//

import Foundation
import CoreData


extension Pin {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Pin> {
        return NSFetchRequest<Pin>(entityName: "Pin")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var flickrPages: Int32
    @NSManaged public var flickrTotalCount: Int32
    @NSManaged public var photos: NSSet?

}

// MARK: Generated accessors for photos
extension Pin {

    @objc(addPhotosObject:)
    @NSManaged public func addToPhotos(_ value: Photo)

    @objc(removePhotosObject:)
    @NSManaged public func removeFromPhotos(_ value: Photo)

    @objc(addPhotos:)
    @NSManaged public func addToPhotos(_ values: NSSet)

    @objc(removePhotos:)
    @NSManaged public func removeFromPhotos(_ values: NSSet)

}
