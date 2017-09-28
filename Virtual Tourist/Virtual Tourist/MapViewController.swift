//
//  ViewController.swift
//  Virtual Tourist
//
//  Created by Jason Wedepohl on 2017/09/28.
//  Copyright © 2017 Jason Wedepohl. All rights reserved.
//

import UIKit
import MapKit

class MapViewController: UIViewController, MKMapViewDelegate {
	
	//MARK: Constants
	
	let pinReuseID = "Pin"
	let deletePrompt = "Tap pins to delete"
	let deletePromptHeight: CGFloat = 40
	let deletePromptFontSize: CGFloat = 21
	
	//MARK: Properties
	
	var deletePromptView: UITextView!
	var editingPins = false
	var pins = [Pin]()
	
	//MARK: Outlets
	
	@IBOutlet var mapView: MKMapView!
	
	//MARK: UIViewController overrides

	override func viewDidLoad() {
		super.viewDidLoad()
		
		let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(addAnnotation(sender:)))
		view.addGestureRecognizer(longPressRecognizer)
		
		setNavBarButton(.edit, #selector(editAnnotations))
	}
	
	@objc private func addAnnotation(sender: UILongPressGestureRecognizer) {
		if sender.state != .began { return }
		let touchLocation = sender.location(in: mapView)
		let mapLocation = mapView.convert(touchLocation, toCoordinateFrom: mapView)
		
		let pin = Pin(mapLocation.latitude, mapLocation.longitude)
		pins.append(pin)
		
		let annotation = MKPointAnnotation()
		annotation.coordinate = mapView.convert(touchLocation, toCoordinateFrom: mapView)
		annotation.title = pin.id
		
		mapView.addAnnotation(annotation)
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
			self.setNavBarButton(.done, #selector(self.doneEditing))
		})
	}
	
	@objc private func doneEditing() {
		navigationItem.rightBarButtonItem?.isEnabled = false
		
		UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut, animations: {
			self.view.frame.origin.y = 0
		}, completion: { finished in
			self.editingPins = false
			self.deletePromptView.removeFromSuperview()
			self.setNavBarButton(.edit, #selector(self.editAnnotations))
		})
	}
	
	private func setNavBarButton(_ item: UIBarButtonSystemItem, _ action: Selector) {
		navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: item, target: self, action: action)
	}
	
	//MARK: MKMapViewDelegate implementation
	
	// Create annotation view
	func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
		var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: pinReuseID) as? MKPinAnnotationView
		
		if pinView == nil {
			pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: pinReuseID)
			pinView!.pinTintColor = .red
			pinView!.animatesDrop = true
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
			let pinIndex = findPin(annotation.title!!)
			pins.remove(at: pinIndex!)
		} else {
			//TODO: navigate to photos for given pin
		}
	}
	
	private func findPin(_ id: String) -> Int? {
		var index = 0
		while index < pins.count {
			let pin = pins[index]
			if pin.id == id {
				return index
			}
			index += 1
		}
		return nil
	}
}

