//
//  CanvasViewController.swift
//  GroundGame
//
//  Created by Josh Smith on 9/30/15.
//  Copyright © 2015 Josh Smith. All rights reserved.
//

import UIKit
import MapKit
import Dollar

class CanvasViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate, UIGestureRecognizerDelegate {
    
    @IBOutlet weak var mapView: MKMapView!

    // MARK: - Location Button State
    
    enum LocationButtonState {
        case None, Follow, FollowWithHeading
    }
    
    var locationButtonState: LocationButtonState = .None {
        didSet {
            switch locationButtonState {
            case .None:
                mapView.userTrackingMode = MKUserTrackingMode.None
                locationButton.setImage(UIImage(named: "gray-arrow"), forState: UIControlState.Normal)
            case .Follow:
                mapView.userTrackingMode = MKUserTrackingMode.Follow
                locationButton.setImage(UIImage(named: "blue-arrow"), forState: UIControlState.Normal)
            case .FollowWithHeading:
                mapView.userTrackingMode = MKUserTrackingMode.FollowWithHeading
                locationButton.setImage(UIImage(named: "blue-compass"), forState: UIControlState.Normal)
            }
        }
    }
    
    @IBOutlet weak var locationButton: UIButton! {
        didSet {
            locationButton.setImage(UIImage(named: "blue-arrow"), forState: UIControlState.Selected)
        }
    }
    @IBOutlet weak var addLocationButton: UIButton!
    
    @IBAction func addLocation(sender: UIButton) {
        self.performSegueWithIdentifier("AddLocation", sender: self)
    }
    
    // MARK: - Lifecycle Functions
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Set up our location manager
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.requestWhenInUseAuthorization()
            locationManager.startUpdatingLocation()
            
            if let location = locationManager.location {
                centerMapOnLocation(location)
                locationButtonState = .Follow
            }
        }
        
        // Set the map view
        mapView.delegate = self
        mapView?.showsUserLocation = true
        
        // Track pan gestures
        let panRecognizer: UIPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: "didDragMap:")
        panRecognizer.delegate = self
        self.mapView.addGestureRecognizer(panRecognizer)
        
        // Track pinch gestures
        let pinchRecognizer: UIPinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: "didZoomMap:")
        pinchRecognizer.delegate = self
        self.mapView.addGestureRecognizer(pinchRecognizer)

        // Track tap gestures
        let tapRecognizer: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: "didZoomMap:")
        tapRecognizer.delegate = self
        self.mapView.addGestureRecognizer(tapRecognizer)
    }
    
    
    // MARK: - Map Interactions
    
    let regionRadius: CLLocationDistance = 1000
    
    var changedRegion: Bool = false

    @IBAction func changeLocationButtonState(sender: UIButton) {

        switch locationButtonState {
        case .None:
            locationButtonState = .Follow
        case .Follow:
            locationButtonState = .FollowWithHeading
        case .FollowWithHeading:
            locationButtonState = .Follow
        }
    }

    func centerMapOnLocation(location: CLLocation) {
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate,
            regionRadius * 2.0, regionRadius * 2.0)
        mapView.setRegion(coordinateRegion, animated: true)
    }
    
    func didDragMap(gestureRecognizer: UIGestureRecognizer) {
        if gestureRecognizer.state == UIGestureRecognizerState.Began {
            locationButtonState = .None
        }
    }
    
    func didZoomMap(gestureRecognizer: UIGestureRecognizer) {
        if gestureRecognizer.state == UIGestureRecognizerState.Began {
            locationButtonState = .None
        }
    }

    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func getFurthestDistanceFromRegionCenter(region: MKCoordinateRegion, center: CLLocationCoordinate2D) -> CLLocationDistance {
        let latitudeDelta = region.span.latitudeDelta
        let longitudeDelta = region.span.longitudeDelta
        
        let longestDelta = max(latitudeDelta, longitudeDelta)
        
        let centerLocation = CLLocation.init(latitude: center.latitude, longitude: center.longitude)
        var newLocation = centerLocation
        if longestDelta == latitudeDelta {
            newLocation = CLLocation.init(latitude: center.latitude + latitudeDelta / 2, longitude: center.longitude)
        } else {
            newLocation = CLLocation.init(latitude: center.latitude, longitude: center.longitude + longitudeDelta / 2)
        }
        
        let distance = centerLocation.distanceFromLocation(newLocation)
        return distance
    }
    
    func mapView(mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        self.changedRegion = true
        
        let center = mapView.centerCoordinate
        let distance = getFurthestDistanceFromRegionCenter(mapView.region, center: center)
        
        let addressService = AddressService()
        
        addressService.getAddresses(center.latitude, longitude: center.longitude, radius: distance) { (addressResults) in
            
            if let addresses = addressResults {

                var annotationsToAdd: [MKAnnotation] = []
                var annotationsToRemove: [MKAnnotation] = []
                var annotationsToKeep: [MKAnnotation] = []
                
                for address in addresses {
                    let result = self.annotationsContainAddress(address)
                    if result.success {
                        annotationsToKeep.append(result.annotation!)
                    } else {
                        let annotation = self.addressToPin(address)
                        annotationsToKeep.append(annotation)
                        annotationsToAdd.append(annotation)
                    }
                }
                
                annotationsToRemove = self.differenceBetweenAnnotations(self.mapView.annotations, secondArray: annotationsToKeep)
                
                print("Removing \(annotationsToRemove.count) annotations")
                print("Should keep \(annotationsToKeep.count) annotations")
                print("Should add \(annotationsToAdd.count) annotations")
                
                mapView.removeAnnotations(annotationsToRemove)
                mapView.addAnnotations(annotationsToAdd)
            }
        }
    }
    
    func differenceBetweenAnnotations(firstArray: [MKAnnotation], secondArray: [MKAnnotation]) -> [MKAnnotation] {
        var map: [MKAnnotation] = []
        
        outerLoop: for elem in firstArray {
            if elem.isKindOfClass(MKUserLocation) {
                continue
            }
            map.append(elem)
            for secondElem in secondArray {
                if elem.coordinate.latitude == secondElem.coordinate.latitude
                && elem.coordinate.longitude == secondElem.coordinate.longitude
                && elem.title! == secondElem.title!
                && elem.subtitle! == secondElem.subtitle! {
                    map.removeLast()
                    continue outerLoop
                }
            }
        }
        
        return map
    }
    
    func mapView(mapView: MKMapView, didChangeUserTrackingMode mode: MKUserTrackingMode, animated: Bool) {
        
        // When the compass is tapped in iOS 9, change the button state back to tracking
        if mode == .Follow {
            if locationButtonState != .Follow {
                locationButtonState = .Follow
            }
        }
    }
    
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {

        if annotation.isKindOfClass(AddressPointAnnotation) {
            let addressAnnotation = annotation as? AddressPointAnnotation
            
            var pinAnnotation = mapView.dequeueReusableAnnotationViewWithIdentifier("Pin")

            if pinAnnotation == nil {
                pinAnnotation = MKAnnotationView.init(annotation: addressAnnotation, reuseIdentifier: "Pin")
            }
            
            pinAnnotation?.image = addressAnnotation?.image
            
            pinAnnotation?.layer.anchorPoint = CGPointMake(0.5, 1.0)
            pinAnnotation?.canShowCallout = true
        
            return pinAnnotation

        } else {
            return nil
        }
    }
    
    func addressToPin(address: Address) -> AddressPointAnnotation {
        let dropPin = AddressPointAnnotation()

        dropPin.result = address.result
        dropPin.coordinate = address.coordinate!
        dropPin.title = address.title
        dropPin.subtitle = address.subtitle
        
        return dropPin
    }
    
    func annotationsContainAddress(address: Address) -> (success: Bool, annotation: AddressPointAnnotation?) {
        for existingAnnotation in self.mapView.annotations {
            if let existingAddressAnnotation = existingAnnotation as? AddressPointAnnotation {
                if existingAddressAnnotation.coordinate.latitude == address.latitude
                    && existingAddressAnnotation.coordinate.longitude == address.longitude
                    && existingAddressAnnotation.title == address.title
                    && existingAddressAnnotation.subtitle == address.subtitle
                {
                    print("Contains address")
                    return (true, existingAddressAnnotation)
                }
            }
        }
        return (false, nil)
    }
    
    // MARK: - Location Fetching
    
    let locationManager = CLLocationManager()
    let geocoder = CLGeocoder()
    
    var lastKnownLocation: CLLocation?
    var locality: String?
    var administrativeArea: String?
    
    @IBAction func findMyLocation(sender: AnyObject) {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let currentLocation = manager.location!
        
        geocoder.reverseGeocodeLocation(currentLocation) { (placemarks, error) -> Void in
            if let placemarksArray = placemarks {
                if placemarksArray.count > 0 {
                    let pm = placemarks![0] as CLPlacemark
                    if let localityString = pm.locality,
                        let administrativeAreaString = pm.administrativeArea {
                            self.locality = localityString
                            self.administrativeArea = administrativeAreaString
                    }
                }
            }
        }
        
        // Update the last known location
        lastKnownLocation = currentLocation
    }
    
    func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
        print("Error while updating location " + error.localizedDescription)
    }
}