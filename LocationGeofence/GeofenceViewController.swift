//
//  AppDelegate.swift
//  LocationGeofence
//
//  Created by Ciprian Rarau on 06/07/2017.
//  Copyright (c) 2017 Ciprian Rarau. All rights reserved.
//

import UIKit
import MapKit

protocol GeofenceViewControllerDelegate {
    func addGeofence(region: LocationCircularRegion, add: Bool)
    func deleteGeofence(identifier:String)
}

class GeofenceViewController: UITableViewController, MKMapViewDelegate {
    @IBOutlet weak var eventTypeSegmentedControl: UISegmentedControl!
    @IBOutlet weak var radiusTextField: UITextField!
    @IBOutlet weak var noteTextField: UITextField!
    @IBOutlet weak var mapView: MKMapView!
    
    var add: Bool = true
    var detailItem: LocationCircularRegion?
    var circle:MKCircle?
    
    var delegate: GeofenceViewControllerDelegate!
    let pointAnnotation = MKPointAnnotation()
    var identifier = NSUUID().uuidString
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.mapView.delegate = self
        self.mapView.mapType = MKMapType.hybrid
        
        if(!add && detailItem != nil){
            self.navigationItem.title = "Edit"
            if let detail: LocationCircularRegion = self.detailItem {
                self.identifier = detail.identifier
                switch detail.type {
                case .Enter:
                    self.eventTypeSegmentedControl.selectedSegmentIndex=0
                    break
                case .Exit:
                    self.eventTypeSegmentedControl.selectedSegmentIndex=1
                    break
                }
                self.mapView.setRegion(MKCoordinateRegionMake(detail.coordinate, MKCoordinateSpanMake(1, 1)), animated: false)
                self.noteTextField.text = detail.note
                self.radiusTextField.text = Int(detail.radius).description
                self.drawCircleWithRadius(center: detail.coordinate, radius: detail.radius)
            }
        } else {
            if (detailItem == nil) {
                let currentLocation = LocationGeofenceTracker.sharedInstance.currentLocation()
                if let currentLocation = currentLocation {
                    self.mapView.centerCoordinate = currentLocation.coordinate
                    self.drawCircleWithRadius(center: currentLocation.coordinate, radius:100)
                }
            } else {
                self.mapView.centerCoordinate = self.detailItem!.coordinate
                self.drawCircleWithRadius(center: self.detailItem!.coordinate, radius:100)
            }
        }
        
        self.mapView.setVisibleMapRect(self.circle!.boundingMapRect, edgePadding: UIEdgeInsetsMake(30, 30, 30, 30), animated: true)
        self.mapView.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressGesture)))
    }
    
    func handleLongPressGesture(sender:UIGestureRecognizer) {
        if (sender.state == UIGestureRecognizerState.ended) {
        } else {
            let point = sender.location(in: self.mapView)
            let centerCoordinate = self.mapView.convert(point, toCoordinateFrom: self.mapView)
            self.mapView.setCenter(centerCoordinate, animated: true)
        }
    }

    func drawCircleWithRadius(center:CLLocationCoordinate2D, radius:Double) {
        self.mapView.removeAnnotation(pointAnnotation)
    
        pointAnnotation.coordinate = center
        pointAnnotation.title = "geofence"
        self.mapView.addAnnotation(pointAnnotation)
        
        if let _ = circle {
            self.mapView.remove(self.circle!)
        }
        self.circle = MKCircle(center: self.mapView.centerCoordinate, radius: radius)
        self.mapView.add(self.circle!)
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay is MKCircle {
            let circleRenderer = MKCircleRenderer(circle: overlay as! MKCircle)
            circleRenderer.strokeColor = UIColor.blue
            circleRenderer.lineWidth = 2.0
            circleRenderer.fillColor = UIColor.blue.withAlphaComponent(0.2)
            return circleRenderer
        }
        return MKOverlayRenderer()
    }
    
    func getNewRadius() -> CLLocationDistance {
        let centerLocation = CLLocation(latitude: self.mapView.centerCoordinate.latitude, longitude: self.mapView.centerCoordinate.longitude)
        let topCenterCorner = self.mapView.convert(CGPoint(x: self.mapView.frame.size.width / 2.0, y: 0), toCoordinateFrom: self.mapView)
        
        
        return centerLocation.distance(from: CLLocation(latitude: topCenterCorner.latitude, longitude: topCenterCorner.longitude))
    }

    @IBAction func textFieldEditingChanged(_ sender: UITextField) {
        if let radius = Double(self.radiusTextField.text!) {
            self.drawCircleWithRadius(center: self.mapView.centerCoordinate, radius:radius)
            let mapRadius = getNewRadius()
            if mapRadius < radius {
                self.mapView.setVisibleMapRect(self.circle!.boundingMapRect, edgePadding: UIEdgeInsetsMake(30, 30, 30, 30), animated: true)
            }
        }
    }
    
    @IBAction func onCancel(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        if let radius = Double(self.radiusTextField.text!) {
            self.drawCircleWithRadius(center: self.mapView.centerCoordinate, radius:radius)
        }
    }
    
    @IBAction func saveGeofence(_ sender: Any) {
        let coordinate = mapView.centerCoordinate
        let radius = Double(radiusTextField.text!)!
        let note = noteTextField.text!
        let eventType = (eventTypeSegmentedControl.selectedSegmentIndex == 0) ? LocationCircularRegionType.Enter : LocationCircularRegionType.Exit
        
        let region = LocationCircularRegion(identifier: self.identifier, coordinate: coordinate, radius: radius, type: eventType, note:note)
        delegate.addGeofence(region: region, add: add)
        
        self.navigationController?.popViewController(animated: true)
    }

    @IBAction func deleteAction(_ sender: Any) {
        self.delegate.deleteGeofence(identifier: self.identifier)
        
        self.navigationController?.popViewController(animated: true)
    }
}
