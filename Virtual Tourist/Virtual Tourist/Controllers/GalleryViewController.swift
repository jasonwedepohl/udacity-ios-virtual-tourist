//
//  GalleryViewController.swift
//  Virtual Tourist
//
//  Created by Jason Wedepohl on 2017/09/29.
//  Copyright © 2017 Jason Wedepohl. All rights reserved.
//

import UIKit
import MapKit

class GalleryViewController: UIViewController {
	//MARK: Constants
	
	let pinReuseID = "Pin"
	let cellIdentifier = "PhotoCell"
	let cellsPerRow:CGFloat = 3;
	let cellSpacing:CGFloat = 2;
	
	//MARK: Properties
	
	var pin: Pin!
	var photos = [Photo]()
	
	//MARK: Outlets
	
	@IBOutlet var mapView: MKMapView!
	@IBOutlet var photoCollectionView: UICollectionView!
	@IBOutlet var photoCollectionViewFlowLayout: UICollectionViewFlowLayout!
	@IBOutlet var newCollectionButton: UIButton!
	@IBOutlet var removeSelectedButton: UIButton!
	
	//MARK: Actions
	
	@IBAction func newCollection() {
		newCollectionButton.isEnabled = false
		photos = [Photo]()
		photoCollectionView.reloadData()
		
		FlickrClient.instance.getNearbyPhotos(pin) { (successful, photos, displayError) in
			DispatchQueue.main.async {
				self.newCollectionButton.isEnabled = true
				
				if successful {
					self.photos = photos!
					
					self.photoCollectionView.reloadData()
				} else {
					ErrorAlert.show(self, displayError)
				}
			}
		}
	}
	
	@IBAction func removeSelectedPictures() {
		photoCollectionView.performBatchUpdates({
			if let indexPathsToDelete = photoCollectionView.indexPathsForSelectedItems {
				
				//remove photos from underlying array
				var newPhotos = [Photo]()
				let indicesOfPhotosToDelete = indexPathsToDelete.map { $0.row }
				
				for (photoIndex, photo) in photos.enumerated() {
					if !indicesOfPhotosToDelete.contains(photoIndex) {
						newPhotos.append(photo)
					}
				}
				
				photos = newPhotos
				
				//remove photo views from collection view
				photoCollectionView.deleteItems(at: indexPathsToDelete)
			}
		})
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
    }
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		setFlowLayout()
		newCollection()
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
	// Create annotation view
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
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return photos.count
	}
	
	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as! PhotoCollectionViewCell
		let photo = photos[indexPath.row]
		
		cell.loadingIndicator.isHidden = false
		cell.loadingIndicator.startAnimating()
		cell.imageView.backgroundColor = UIColor.white
		cell.imageView.image = nil
		
		FlickrClient.instance.downloadImage(photo.url) { (successful, imageData, displayError) in
			if successful {
				DispatchQueue.main.async {
					self.photos[indexPath.row].imageData = imageData!
					cell.imageView.image = UIImage(data: imageData!)
					cell.imageView.contentMode = .scaleAspectFill
					cell.loadingIndicator.stopAnimating()
					cell.loadingIndicator.isHidden = true
				}
			} else {
				print("Could not download image: \(displayError!)")
			}
		}
		
		return cell
	}
	
	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		let cell = collectionView.cellForItem(at: indexPath) as! PhotoCollectionViewCell
		
		cell.imageView.image = setAlpha(cell.imageView.image!, 0.5)
		
		removeSelectedButton.isHidden = false
		newCollectionButton.isHidden = true
	}
	
	func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
		let cell = collectionView.cellForItem(at: indexPath) as! PhotoCollectionViewCell
		let photo = photos[indexPath.row]
		
		cell.imageView.image = UIImage(data: photo.imageData!)
		
		if collectionView.indexPathsForSelectedItems!.count == 0 {
			removeSelectedButton.isHidden = true
			newCollectionButton.isHidden = false
		}
	}
	
	private func setAlpha(_ image: UIImage, _ value:CGFloat) -> UIImage {
		UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
		image.draw(at: CGPoint.zero, blendMode: .normal, alpha: value)
		let newImage = UIGraphicsGetImageFromCurrentImageContext()
		UIGraphicsEndImageContext()
		return newImage!
	}
}
