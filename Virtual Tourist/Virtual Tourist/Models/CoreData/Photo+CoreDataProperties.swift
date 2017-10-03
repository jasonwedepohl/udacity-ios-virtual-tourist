//
//  Photo+CoreDataProperties.swift
//  Virtual Tourist
//
//  Created by Jason Wedepohl on 2017/10/03.
//  Copyright © 2017 Jason Wedepohl. All rights reserved.
//
//

import Foundation
import CoreData


extension Photo {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Photo> {
        return NSFetchRequest<Photo>(entityName: "Photo")
    }

    @NSManaged public var data: Data?
    @NSManaged public var url: String?
    @NSManaged public var pin: Pin?

}
