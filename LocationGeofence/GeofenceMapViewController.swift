//
//  AppDelegate.swift
//  LocationGeofence
//
//  Created by Ciprian Rarau on 06/07/2017.
//  Copyright (c) 2017 Ciprian Rarau. All rights reserved.
//

import UIKit
import MapKit

extension UIStoryboard {
    static func loadViewController<T : UIViewController>(identifier: String) -> T? {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        return storyboard.instantiateViewController(withIdentifier: identifier) as? T
    }
}


class GeofenceMapViewController: UIViewController, GeofenceViewControllerDelegate, MKMapViewDelegate, LocationGeofenceTrackerDataSource, LocationGeofenceTrackerDelegate {

    @IBOutlet weak var mapView: MKMapView!
    
    let locationTracker = LocationGeofenceTracker.sharedInstance
    
    var locations:Array<LocationCircularRegion> = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.mapView.showsUserLocation = true
        self.mapView.mapType = .hybrid
        locationTracker.delegate = self
        locationTracker.datasource = self
        
        locationTracker.start()
        
        self.locations = self.loadLocations()
        LocationGeofenceTracker.sharedInstance.reloadGeoFenceLocations()
        
        self.reloadAnnnotations()
        
        self.mapView.showAnnotations(self.mapView.annotations, animated: true)
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressGesture))
        longPress.minimumPressDuration = 1.0
        self.mapView.addGestureRecognizer(longPress)
    }
    
    @IBAction func currentLocationTouchUpInside(_ sender: Any) {
        if let userLocation = LocationGeofenceTracker.sharedInstance.currentLocation() {
            self.mapView.setCenter(userLocation.coordinate, animated: true)
        }
    }
    
    @IBAction func listAction(_ sender: Any) {
        guard let listViewController: GeofenceListViewController = UIStoryboard.loadViewController(identifier: "list") else {
            return
        }
        
        self.navigationController?.pushViewController(listViewController, animated: true)
    }

    func handleLongPressGesture(sender:UIGestureRecognizer) {
        if (sender.state != UIGestureRecognizerState.began) {
            return
        }
        
        guard let createViewController: GeofenceViewController = UIStoryboard.loadViewController(identifier: "geofence") as? GeofenceViewController else {
            return
        }
        
        let centerCoordinate = self.mapView.convert(sender.location(in: self.mapView), toCoordinateFrom: self.mapView)
        createViewController.delegate = self
        createViewController.add = true
        createViewController.detailItem = LocationCircularRegion(identifier: NSUUID().uuidString, coordinate: centerCoordinate, radius: 100, type: LocationCircularRegionType.Enter, note: "")
        
        self.navigationController?.pushViewController(createViewController, animated: true)
    }
    
    func reloadAnnnotations() {
        self.mapView.removeAnnotations(mapView.annotations.filter { $0 !== mapView.userLocation })
        self.mapView.removeOverlays(self.mapView.overlays)
        self.locations = self.loadLocations()
        
        self.mapView.addAnnotations(self.locations.map { GeofencingAnnotation(region: $0) })
        
        let regionOverlays = self.locations.map { (region: LocationCircularRegion) -> MKCircle in
            let circle = GeofencingMKCircle(center: region.coordinate, radius: region.radius)
            circle.type = region.type
            return circle
        }
        self.mapView.addOverlays(regionOverlays)
        
        title = "Geofences (\(locations.count))"
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.reloadAnnnotations()
    }
    
    func addGeofence(region:LocationCircularRegion, add: Bool) {
        if(add) {
            locations.append(region)
        } else {
            if let index = locations.index(where: { $0.identifier == region.identifier}) {
                locations[index] = region
            }
        }
        self.saveLocations(locations: self.locations)
        
        self.reloadAnnnotations()
    }
    
    func deleteGeofence(identifier: String) {
        if let index = locations.index(where: { $0.identifier == identifier }) {
            self.locations.remove(at: index)
            self.saveLocations(locations: self.locations)
            
            self.reloadAnnnotations()
        }
    }
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let annotation = annotation as? GeofencingAnnotation else {
            return nil
        }
        
        if let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: "geofencing") as? GeofencingAnnotationView {
            annotationView.annotation = annotation
            annotationView.region = annotation.region
            return annotationView
        } else {
            let annotationView = GeofencingAnnotationView(annotation: annotation, reuseIdentifier: "geofencing")
            annotationView.canShowCallout = true
            
            let removeButton = UIButton(type: .custom)
            removeButton.tag = 1
            removeButton.frame = CGRect(x: 0, y: 0, width: 23, height: 23)
            removeButton.setImage(UIImage(named: "DeleteGeofence")!, for: .normal)
            annotationView.rightCalloutAccessoryView = removeButton

            let editButton = UIButton(type: .custom)
            editButton.tag = 2
            editButton.frame = CGRect(x: 0, y: 0, width: 23, height: 23)
            editButton.setImage(UIImage(named: "EditGeofence")!, for: .normal)
            annotationView.leftCalloutAccessoryView = editButton
        
            return annotationView
        }
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let geofencingOveral = overlay as? GeofencingMKCircle else {
            return MKOverlayRenderer()
        }
        
        let circleRenderer = MKCircleRenderer(overlay: geofencingOveral)
        circleRenderer.lineWidth = 1.0
        
        if (geofencingOveral.type == .Enter) {
            circleRenderer.strokeColor = UIColor.red
            circleRenderer.fillColor = UIColor.red.withAlphaComponent(0.2)
        } else {
            circleRenderer.strokeColor = UIColor.orange
            circleRenderer.fillColor = UIColor.orange.withAlphaComponent(0.2)
        }
        return circleRenderer

    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        guard let annotationView = view as? GeofencingAnnotationView,
            let vc = UIStoryboard.loadViewController(identifier: "geofence") as? GeofenceViewController else {
            return
        }
        
        if (control.tag == 1) {
            self.deleteGeofence(identifier: annotationView.region!.identifier)
            return
        }
        
        vc.delegate = self
        vc.detailItem = annotationView.region
        vc.add = false
        
        self.navigationController?.pushViewController(vc, animated: true)
    }

    func locationsToTrack() -> Array<LocationCircularRegion> {
        return self.loadLocations()
    }
    func didEnterRegion(region:LocationCircularRegion) {
        self.presentLocalNotification(region: region)
    }
    func didExitRegion(region:LocationCircularRegion) {
        self.presentLocalNotification(region: region)
    }
    func locationTrackingError(errorMessage:String) {
        UIAlertController.error(errorMessage)
    }
    func newLocation(location: CLLocation) {
    }
}
