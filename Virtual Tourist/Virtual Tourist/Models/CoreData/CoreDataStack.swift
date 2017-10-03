//
//  CoreDataStack.swift
//  Virtual Tourist
//
//  Created by Jason Wedepohl on 2017/10/02.
//  Copyright © 2017 Jason Wedepohl. All rights reserved.
//

//ATTRIBUTION: This file is a modified version of the CoreDataStack class from Udacity's iOS Persistence course, lesson "Core Data and Concurrency".
//That file is hosted here: https://github.com/udacity/ios-nd-persistence/blob/master/CoolNotes/13-CoreDataAndConcurrency/CoolNotes/CoreDataStack.swift

import CoreData

// MARK: - CoreDataStack

struct CoreDataStack {
	
	// MARK: Singleton
	
	static let instance = CoreDataStack(modelName: "Model")!
	
	// MARK: Properties
	
	private let model: NSManagedObjectModel
	internal let coordinator: NSPersistentStoreCoordinator
	private let modelURL: URL
	internal let dbURL: URL
	internal let persistingContext: NSManagedObjectContext
	let context: NSManagedObjectContext
	
	// MARK: Initializers
	
	init?(modelName: String) {
		
		// Assumes the model is in the main bundle
		guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "momd") else {
			print("Unable to find \(modelName)in the main bundle")
			return nil
		}
		self.modelURL = modelURL
		
		// Try to create the model from the URL
		guard let model = NSManagedObjectModel(contentsOf: modelURL) else {
			print("unable to create a model from \(modelURL)")
			return nil
		}
		self.model = model
		
		// Create the store coordinator
		coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
		
		// Create a persistingContext (private queue) and a child one (main queue)
		// create a context and add connect it to the coordinator
		persistingContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
		persistingContext.persistentStoreCoordinator = coordinator
		
		context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
		context.parent = persistingContext
		
		// Add a SQLite store located in the documents folder
		let fm = FileManager.default
		
		guard let docUrl = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
			print("Unable to reach the documents folder")
			return nil
		}
		
		self.dbURL = docUrl.appendingPathComponent("model.sqlite")
		
		// Options for migration
		let options = [NSInferMappingModelAutomaticallyOption: true,NSMigratePersistentStoresAutomaticallyOption: true]
		
		do {
			try addStoreCoordinator(NSSQLiteStoreType, configuration: nil, storeURL: dbURL, options: options as [NSObject : AnyObject]?)
		} catch {
			print("unable to add store at \(dbURL)")
		}
	}
	
	// MARK: Utils
	
	func addStoreCoordinator(_ storeType: String, configuration: String?, storeURL: URL, options : [NSObject:AnyObject]?) throws {
		try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: dbURL, options: nil)
	}
	
	func save() {
		//Save main context to persisting context on current thread, then save persisting context to base context in background thread
		context.performAndWait() {
			
			if self.context.hasChanges {
				do {
					try self.context.save()
				} catch {
					fatalError("Error while saving main context: \(error)")
				}
				
				// now we save in the background
				self.persistingContext.perform() {
					do {
						try self.persistingContext.save()
					} catch {
						fatalError("Error while saving persisting context: \(error)")
					}
				}
			}
		}
	}
}
