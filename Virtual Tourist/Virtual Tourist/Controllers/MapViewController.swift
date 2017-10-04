//
//  ViewController.swift
//  Virtual Tourist
//
//  Created by Jason Wedepohl on 2017/09/28.
//  Copyright © 2017 Jason Wedepohl. All rights reserved.
//

import CoreData
import UIKit
import MapKit

class MapViewController: UIViewController {
	
	//MARK: Constants
	
	let pinReuseID = "Pin"
	let deletePrompt = "Tap pins to delete"
	let deletePromptHeight: CGFloat = 40
	let deletePromptFontSize: CGFloat = 21
	let gallerySegueIdentifier = "GallerySegue"
	
	//keys for UserDefaults
	let valuesExistKey = "ValuesExist"
	let altitudeKey = "Altitude"
	let headingKey = "Heading"
	let centerLatitudeKey = "CenterLatitude"
	let centerLongitudeKey = "CenterLongitude"
	
	//MARK: Properties
	
	var deletePromptView: UITextView!
	var editingPins = false
	var currentPin: Pin?
	
	//MARK: Outlets
	
	@IBOutlet var mapView: MKMapView!
	
	//MARK: UIViewController overrides

	override func viewDidLoad() {
		super.viewDidLoad()
		
		let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(addAnnotation(sender:)))
		view.addGestureRecognizer(longPressRecognizer)
		
		setEditPinsButton(.edit, #selector(editAnnotations))
		
		//load all pins from main context
		mapView.addAnnotations(Pin.fetchAll())
		
		//set map camera if values are there
		if UserDefaults.standard.bool(forKey: valuesExistKey) {
			let altitude = UserDefaults.standard.double(forKey: altitudeKey)
			let heading = UserDefaults.standard.double(forKey: headingKey)
			let coordinate = CLLocationCoordinate2D(latitude: UserDefaults.standard.double(forKey: centerLatitudeKey),
			                                        longitude: UserDefaults.standard.double(forKey: centerLongitudeKey))
			let camera = MKMapCamera(lookingAtCenter: coordinate, fromDistance: altitude, pitch: 0, heading: heading)
			mapView.setCamera(camera, animated: false)
		}
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if segue.identifier == gallerySegueIdentifier {
			guard let galleryController = segue.destination as? GalleryViewController else {
				print("Expected segue destination to be GalleryViewController but was \(String(describing: segue.destination))")
				return
			}
			
			guard let pin = sender as? Pin else {
				print("Expected sender to be a Pin but was \(String(describing: sender))")
				return
			}
			
			galleryController.pin = pin
			
			//set back bar title on Gallery view to "Back", not "Virtual Tourist"
			let backItem = UIBarButtonItem()
			backItem.title = "Back"
			navigationItem.backBarButtonItem = backItem
		}
	}
	
	@objc private func addAnnotation(sender: UILongPressGestureRecognizer) {
		let touchLocation = sender.location(in: mapView)
		let mapLocation = mapView.convert(touchLocation, toCoordinateFrom: mapView)
		
		switch sender.state {
		case .began:
			//create Pin in main context
			currentPin = Pin(mapLocation, CoreDataStack.instance.context)
			mapView.addAnnotation(currentPin!)
		case .changed:
			//update pin location as user drags
			currentPin!.coordinate = mapLocation
		case .ended:
			CoreDataStack.instance.save()
			currentPin = nil
		default:
			print("Unexpected state \(sender.state) occurred.")
		}
	}
	
	@objc private func editAnnotations() {
		navigationItem.rightBarButtonItem?.isEnabled = false
		
		deletePromptView = UITextView(frame: CGRect(x: 0,
		                                            y: view.frame.origin.y + view.frame.height,
		                                            width: view.frame.width,
		                                            height: deletePromptHeight))
		deletePromptView.text = deletePrompt
		deletePromptView.backgroundColor = UIColor.red
		deletePromptView.textColor = UIColor.white
		deletePromptView.textAlignment = .center
		deletePromptView.font = UIFont(name: deletePromptView.font!.fontName, size: deletePromptFontSize)
		view.addSubview(deletePromptView)
		
		UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn, animations: {
			self.view.frame.origin.y -= self.deletePromptHeight
		}, completion: { finished in
			self.editingPins = true
			self.setEditPinsButton(.done, #selector(self.doneEditing))
		})
	}
	
	@objc private func doneEditing() {
		navigationItem.rightBarButtonItem?.isEnabled = false
		
		UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut, animations: {
			self.view.frame.origin.y = 0
		}, completion: { finished in
			self.editingPins = false
			self.deletePromptView.removeFromSuperview()
			self.setEditPinsButton(.edit, #selector(self.editAnnotations))
		})
	}
	
	//used to toggle pin edit mode button between "Edit" and "Done"
	private func setEditPinsButton(_ item: UIBarButtonSystemItem, _ action: Selector) {
		navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: item, target: self, action: action)
	}
}

//MARK: MKMapViewDelegate

extension MapViewController: MKMapViewDelegate {
	
	func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
		var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: pinReuseID) as? MKPinAnnotationView
		
		if pinView == nil {
			pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: pinReuseID)
			pinView!.pinTintColor = .red
			pinView!.canShowCallout = false
			
			let pin = annotation as! Pin
			pinView!.animatesDrop = pin.mustAnimatePinDrop
		}
		else {
			pinView!.annotation = annotation
		}
		
		return pinView
	}
	
	func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
		guard let annotation = view.annotation else { return }
		
		if editingPins {
			mapView.removeAnnotation(annotation)
			
			//remove pin from main context
			CoreDataStack.instance.context.delete(annotation as! Pin)
			CoreDataStack.instance.save()
		} else {
			//navigate to pin photo collection
			mapView.deselectAnnotation(annotation, animated: false)
			performSegue(withIdentifier: gallerySegueIdentifier, sender: annotation as! Pin)
		}
	}
	
	//remember map view camera
	func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
		UserDefaults.standard.set(true, forKey: valuesExistKey)
		UserDefaults.standard.set(mapView.camera.altitude, forKey: altitudeKey)
		UserDefaults.standard.set(mapView.camera.heading, forKey: headingKey)
		UserDefaults.standard.set(mapView.camera.centerCoordinate.latitude, forKey: centerLatitudeKey)
		UserDefaults.standard.set(mapView.camera.centerCoordinate.longitude, forKey: centerLongitudeKey)
		UserDefaults.standard.synchronize()
	}
}

