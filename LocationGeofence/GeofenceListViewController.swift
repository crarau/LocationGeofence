//
//  AppDelegate.swift
//  LocationGeofence
//
//  Created by Ciprian Rarau on 06/07/2017.
//  Copyright (c) 2017 Ciprian Rarau. All rights reserved.
//
//

import UIKit
import Foundation
import CoreLocation

class GeofenceListViewController: UITableViewController, GeofenceViewControllerDelegate {
    @IBOutlet weak var navbarLabel: UINavigationItem!
    
    var locations:Array<LocationCircularRegion> = []
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.locations = self.loadLocations()
        
        self.locations.forEach {
            print("LocationCircularRegion(identifier: \"\($0.identifier)\", coordinate: CLLocationCoordinate2DMake(\($0.coordinate.latitude), \($0.coordinate.longitude)), radius: \($0.radius), type: .\($0.type.rawValue), note: \"\($0.note) )\")" )
        }
        LocationGeofenceTracker.sharedInstance.reloadGeoFenceLocations()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.locations = self.loadLocations()
        if let currentLocation = LocationGeofenceTracker.sharedInstance.currentLocation() {
            let closestLocations = self.locations.map { (region:LocationCircularRegion) -> LocationCircularRegionDistance in
                return LocationCircularRegionDistance(region.location().distance(from: currentLocation), region)
                }.sorted(by: {$0.distance < $1.distance})
            
            self.locations = closestLocations.map({ $0.region })
        }
        self.reloadData()
    }
    
    func reloadData() {
        title = "Geofences (\(locations.count))"
        self.saveLocations(locations: self.locations)
        self.tableView.reloadData()
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return locations.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let region = self.locations[indexPath.row]
        cell.textLabel!.text = "\(region.note)"
        
        if let currentLocation = LocationGeofenceTracker.sharedInstance.currentLocation() {
            let distance = currentLocation.distance(from: region.location())
            cell.detailTextLabel!.text = "\(region.type.rawValue) - \(Int(distance))m away"
        } else {
            cell.detailTextLabel!.text = "\(region.type.rawValue)"
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "geofence") as! GeofenceViewController
        vc.delegate = self
        vc.detailItem = self.locations[indexPath.row]
        vc.add = false
        
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func addGeofence(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "geofence") as! GeofenceViewController
        vc.delegate = self
        vc.add = true
        
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func mapAction(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            removeGeotification(indexPath: indexPath)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
    }
    
    func addGeofence(region:LocationCircularRegion, add: Bool) {
        if(add) {
            locations.append(region)
        } else {
            let index = locations.index(where: { (r: LocationCircularRegion) -> Bool in
                return r.identifier == region.identifier
            })
            if let index = index {
                locations[index] = region
            }
        }
        self.reloadData()
    }
    
    func removeGeotification(indexPath: IndexPath) {
        locations.remove(at: indexPath.row)
        self.saveLocations(locations: self.locations)
        self.tableView.reloadData()
    }
    
    func deleteGeofence(identifier: String) {
        let index = locations.index(where: { (r: LocationCircularRegion) -> Bool in
            return r.identifier == identifier
        })
        if let index = index {
            locations.remove(at: index)
            self.reloadData()
        }
    }
}

