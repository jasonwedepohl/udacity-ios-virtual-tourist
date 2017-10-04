//
//  GalleryViewController.swift
//  Virtual Tourist
//
//  Created by Jason Wedepohl on 2017/09/29.
//  Copyright © 2017 Jason Wedepohl. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class GalleryViewController: UIViewController {
	//MARK: Constants
	
	let pinReuseID = "Pin"
	let cellIdentifier = "PhotoCell"
	let cellsPerRow:CGFloat = 3;
	let cellSpacing:CGFloat = 2;
	
	//MARK: Properties
	
	let waitingSpinner = WaitingSpinner()
	var pin: Pin!
	var insertedIndexPaths: [IndexPath]!
	var updatedIndexPaths: [IndexPath]!
	var deletedIndexPaths: [IndexPath]!
	var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>!
	
	//MARK: Outlets
	
	@IBOutlet var mapView: MKMapView!
	@IBOutlet var photoCollectionView: UICollectionView!
	@IBOutlet var photoCollectionViewFlowLayout: UICollectionViewFlowLayout!
	@IBOutlet var newCollectionButton: UIButton!
	@IBOutlet var removeSelectedButton: UIButton!
	@IBOutlet var noPhotosLabel: UILabel!
	
	//MARK: Actions
	
	@IBAction func newCollection() {
		waitingSpinner.show(view)
		noPhotosLabel.isHidden = true
		newCollectionButton.isEnabled = false
		
		//delete photos for given pin from main context
		if let photos = fetchedResultsController.fetchedObjects as? [Photo] {
			for photo in photos {
				CoreDataStack.instance.context.delete(photo)
			}
		}
		CoreDataStack.instance.save()
		
		if pin.flickrPages == Pin.nilValueForInt {
			//we don't know the number of pages of photos yet
			FlickrClient.instance.getNearbyPhotos(pin, completionForNewCollection(_:_:))
		} else {
			//we know the number of pages, so choose a random one
			FlickrClient.instance.getRandomPageOfNearbyPhotos(pin, completionForNewCollection(_:_:))
		}
	}
	
	private func completionForNewCollection(_ successful: Bool, _ displayError: String?) {
		DispatchQueue.main.async {
			self.waitingSpinner.hide()
			self.newCollectionButton.isEnabled = true
			
			if successful {
				if self.pin.flickrTotalCount == 0 {
					self.noPhotosLabel.isHidden = false
				} else {
					//fetch photos for pin from main context
					self.performFetch()
					self.photoCollectionView.reloadData()
				}
			} else {
				ErrorAlert.show(self, displayError)
			}
		}
	}
	
	@IBAction func removeSelectedPictures() {
		toggleButtons(deleteMode: false)
		
		if let indexPathsToDelete = photoCollectionView.indexPathsForSelectedItems {
			
			//delete selected photos from main context, FRC delegate will handle collection view updates
			for indexPath in indexPathsToDelete {
				let photo = fetchedResultsController.object(at: indexPath) as! Photo
				CoreDataStack.instance.context.delete(photo)
			}
			CoreDataStack.instance.save()
		}
	}
	
	//MARK: UIViewController overrides

    override func viewDidLoad() {
        super.viewDidLoad()
		
		//center pin location on map
		let coordinate = CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
		let span = MKCoordinateSpanMake(0.1, 0.1)
		let region = MKCoordinateRegion(center: coordinate, span: span)
		mapView.setRegion(region, animated: true)
		mapView.isZoomEnabled = false
		mapView.isScrollEnabled = false
		mapView.isPitchEnabled = false
		mapView.isRotateEnabled = false
		mapView.delegate = self
		
		//add pin to map
		let annotation = MKPointAnnotation()
		annotation.coordinate = coordinate
		mapView.addAnnotation(annotation)
		
		photoCollectionView.dataSource = self
		photoCollectionView.delegate = self
		photoCollectionView.allowsMultipleSelection = true
		setFlowLayout()
		
		//init FRC and tell it to get photos for the given pin from main context
		let fetchRequest = Photo.getFetchRequest(forPin: pin)
		
		fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
		                                                      managedObjectContext: CoreDataStack.instance.context,
		                                                      sectionNameKeyPath: nil,
		                                                      cacheName: nil)
		fetchedResultsController.delegate = self
		performFetch()
		
		if (pin.flickrTotalCount == Pin.nilValueForInt) {
			newCollection()
		} else if (pin.flickrTotalCount == 0) {
			noPhotosLabel.isHidden = false
		}
    }
	
	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		super.viewWillTransition(to: size, with: coordinator)
		
		//change flow layout as orientation changes
		coordinator.animate(alongsideTransition: { _ in
			self.setFlowLayout()
		}, completion: nil)
	}
	
	override func didRotate(from fromInterfaceOrientation: UIInterfaceOrientation) {
		//change flow layout after orientation changes
		setFlowLayout()
	}
	
	private func setFlowLayout() {
		if photoCollectionViewFlowLayout == nil {
			/*
			sometimes flowLayout is nil during orientation change
			e.g. if simulator is in landscape mode, app launches in portrait mode then rotates immediately, before the view has been loaded
			*/
			return;
		}
		
		let numberOfSpaces:CGFloat = 2 * (cellsPerRow - 1)
		let dimension = (view.frame.width - (numberOfSpaces * cellSpacing)) / cellsPerRow
		
		photoCollectionViewFlowLayout.minimumInteritemSpacing = cellSpacing
		photoCollectionViewFlowLayout.minimumLineSpacing = cellSpacing
		photoCollectionViewFlowLayout.itemSize = CGSize(width: dimension, height: dimension)
	}
}

//MARK: MKMapViewDelegate extension

extension GalleryViewController: MKMapViewDelegate {
	
	func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
		var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: pinReuseID) as? MKPinAnnotationView
		
		if pinView == nil {
			pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: pinReuseID)
			pinView!.pinTintColor = .red
			pinView!.canShowCallout = false
		}
		else {
			pinView!.annotation = annotation
		}
		
		return pinView
	}
}

//MARK: UICollectionViewDataSource + UICollectionViewDelegate extension

extension GalleryViewController: UICollectionViewDataSource, UICollectionViewDelegate {
	func numberOfSections(in collectionView: UICollectionView) -> Int {
		if let sections = fetchedResultsController.sections {
			return sections.count
		}
		return 0
	}
	
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		if let sections = fetchedResultsController.sections {
			return sections[section].numberOfObjects
		}
		return 0
	}
	
	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as! PhotoCollectionViewCell
		let photo = fetchedResultsController.object(at: indexPath) as! Photo
		
		cell.imageView.backgroundColor = UIColor.white
		cell.imageView.contentMode = .scaleAspectFill
		
		if let data = photo.data {
			cell.imageView.image = UIImage(data: data)
			cell.loadingIndicator.stopAnimating()
			cell.loadingIndicator.isHidden = true
		}
		else {
			cell.loadingIndicator.isHidden = false
			cell.loadingIndicator.startAnimating()
			cell.imageView.image = nil
		}
		
		return cell
	}
	
	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		let cell = collectionView.cellForItem(at: indexPath) as! PhotoCollectionViewCell
		
		//make image slightly transparent to indicate that it is selected
		cell.imageView.image = setAlpha(cell.imageView.image!, 0.5)
		
		toggleButtons(deleteMode: true)
	}
	
	func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
		let cell = collectionView.cellForItem(at: indexPath) as! PhotoCollectionViewCell
		let photo = fetchedResultsController.object(at: indexPath) as! Photo
		
		//make image opaque to indicate that it is deselected
		cell.imageView.image = UIImage(data: photo.data!)
		
		if collectionView.indexPathsForSelectedItems!.count == 0 {
			toggleButtons(deleteMode: false)
		}
	}
	
	func toggleButtons(deleteMode: Bool) {
		removeSelectedButton.isHidden = !deleteMode
		newCollectionButton.isHidden = deleteMode
	}
	
	private func setAlpha(_ image: UIImage, _ value:CGFloat) -> UIImage {
		UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
		image.draw(at: CGPoint.zero, blendMode: .normal, alpha: value)
		let newImage = UIGraphicsGetImageFromCurrentImageContext()
		UIGraphicsEndImageContext()
		return newImage!
	}
}

//MARK: NSFetchedResultsControllerDelegate implementation

extension GalleryViewController: NSFetchedResultsControllerDelegate {
	
	func performFetch() {
		do {
			try fetchedResultsController.performFetch()
		} catch let e as NSError {
			print("Error while trying to perform a search: \n\(e)\n\(fetchedResultsController)")
		}
	}
	
	func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
		insertedIndexPaths = []
		updatedIndexPaths = []
		deletedIndexPaths = []
	}
	
	func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
	                didChange anObject: Any,
	                at indexPath: IndexPath?,
	                for type: NSFetchedResultsChangeType,
	                newIndexPath: IndexPath?) {
		
		switch type {
		case .insert:
			insertedIndexPaths.append(newIndexPath!)
		case .delete:
			deletedIndexPaths.append(indexPath!)
		case .update:
			updatedIndexPaths.append(indexPath!)
		case .move:
			print("We aren't doing moves so this should never be seen.")
		}
	}
	
	func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
		photoCollectionView.performBatchUpdates({
			self.photoCollectionView.insertItems(at: self.insertedIndexPaths)
			self.photoCollectionView.deleteItems(at: self.deletedIndexPaths)
			self.photoCollectionView.reloadItems(at: self.updatedIndexPaths)
		}, completion: nil)
	}
}
