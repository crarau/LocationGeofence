//
//  LocationTracker.swift
//  LocationGeofence
//
//  Created by Ciprian Rarau on 06/07/2017.
//  Copyright (c) 2017 Ciprian Rarau. All rights reserved.
//


import Foundation
import CoreLocation

protocol LocationGeofenceTrackerDelegate {
    func didEnterRegion(region:LocationCircularRegion)
    func didExitRegion(region:LocationCircularRegion)

    func newLocation(location:CLLocation)
}

protocol LocationGeofenceTrackerDataSource {
    func locationsToTrack() -> Array<LocationCircularRegion>
}

typealias LocationCircularRegionDistance = (distance:CLLocationDistance, region:LocationCircularRegion)

class LocationGeofenceTracker: NSObject,CLLocationManagerDelegate {
    static public let sharedInstance = LocationGeofenceTracker()

    public var datasource:LocationGeofenceTrackerDataSource!
    public var delegate:LocationGeofenceTrackerDelegate!
    
    let manager = CLLocationManager()
    var locationsToTrack:Array<LocationCircularRegion> = []
    var insideCircularRegions:Array<String> = []

    
    var prevLocation:CLLocation?
    
    public override init() {
        super.init()
        
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.startUpdatingLocation()
        manager.startMonitoringSignificantLocationChanges()
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationDidBecomeActive, object: nil, queue: nil) { _ in
            self.wakeUp()
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationWillResignActive, object: nil, queue: nil) { _ in
            self.sleep()
        }
    }
    
    public func start() {
        let status = CLLocationManager.authorizationStatus;
        if (status() == CLAuthorizationStatus.notDetermined) {
            self.manager.requestAlwaysAuthorization()
        }
    }
    
    public func wakeUp() {
        self.manager.monitoredRegions.forEach { self.manager.requestState(for: $0) }
        self.manager.startUpdatingLocation()
    }
    
    public func sleep() {
        self.manager.stopUpdatingLocation()
    }
    
    
    public func reloadGeoFenceLocations() {
        locationsToTrack = datasource.locationsToTrack()
        
        guard let currentLocation = self.manager.location else {
                return
        }
        
        let closest20 = locationsToTrack.map { (region:LocationCircularRegion) -> LocationCircularRegionDistance in
            return LocationCircularRegionDistance(region.location().distance(from: currentLocation), region)
            }.sorted(by: {$0.distance < $1.distance}).map({$0.region.region()}).takeElements(elementCount: 20)
        
        let regionsNotInClosest20 = manager.monitoredRegions.filter({ (region: CLRegion) -> Bool in
            return !closest20.contains(where: { (regionToMonitor: CLRegion) -> Bool in
                return region.identifier == regionToMonitor.identifier
            })
        })
        
        let regionsToStartMonitoring = closest20.filter({ (regionToMonitor: CLRegion) -> Bool in
            return !self.manager.monitoredRegions.contains(where: { (monitoredRegion: CLRegion) -> Bool in
                return monitoredRegion.identifier == regionToMonitor.identifier
            })
        })
        
        print("TRACKER will stop monitoring \(regionsNotInClosest20.count) regions")
        print("TRACKER will start monitoring \(regionsToStartMonitoring.count) regions")
        
        regionsNotInClosest20.forEach {
            print("TRACKER stoped monitoring region \(String(describing: self.locationCircularRegion(region: $0)))")
            self.manager.stopMonitoring(for: $0)
        }
        regionsToStartMonitoring.forEach({
            if let circularRegion = self.locationCircularRegion(region: $0) {
                print("TRACKER started monitoring region \(circularRegion)")
            }
            self.manager.startMonitoring(for: $0)
        })
        
        let currentlyMonitoredRegions = self.manager.monitoredRegions.map({
            if let region = locationCircularRegion(region: $0) {
                return region.note
            } else {
                return "unknown"
            }
        }).joined(separator: ", ")
        print("TRACKER currently monitoring \(currentlyMonitoredRegions)")

    }
    
    public func currentLocation() -> CLLocation? {
        return self.manager.location
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            if let prevLocation = prevLocation, prevLocation.distance(from: location) > 100 {
                self.reloadGeoFenceLocations()
                print("TRACKER current  \(location.debugDescription) distance from prev location: \(prevLocation.distance(from: location))m")
            }
            prevLocation = location
            self.delegate.newLocation(location: location)
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        if !(region is CLCircularRegion) {
            return
        }
        
        let circularRegion = region as! CLCircularRegion
        var newState:CLRegionState = state
        
        if let currentLocation = self.manager.location {
            let extendedRegion = CLCircularRegion(center: circularRegion.center, radius: circularRegion.radius + 1000, identifier: circularRegion.identifier)
            switch (state) {
            case .inside:
                if (!extendedRegion.contains(currentLocation.coordinate)) {
                    self.logRegion(circularRegion: circularRegion)
                    print("TRACKER corrected status from inside to outside \(locationCircularRegion(region: extendedRegion).debugDescription)")
                    newState = CLRegionState.outside
                }
                break;
            case .outside:
                if (circularRegion.contains(currentLocation.coordinate)) {
                    self.logRegion(circularRegion: circularRegion)
                    print("TRACKER corrected status from outside to inside \(locationCircularRegion(region: circularRegion).debugDescription)")
                    newState = CLRegionState.inside
                }
                break;
            case .unknown:
                break
            }
        }
        
        if let regionToTrack = locationCircularRegion(region: region), newState == .inside {
            self.logRegion(circularRegion: circularRegion)
            print("TRACKER status for region \(regionToTrack.debugDescription) is \(newState.rawValue)")
        }
        
        if (newState == CLRegionState.inside) {
            self.insideCircularRegions.append(region.identifier)
        } else {
            self.insideCircularRegions = self.insideCircularRegions.filter({$0 != region.identifier})
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let region = region as? CLCircularRegion,
            let locationRegion = locationCircularRegion(region: region) else {
            return
        }
    
        print("TRACKER received did enter region from iOS \(locationCircularRegion)")
        self.forceLocationUpdate()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.logRegion(circularRegion: region);
            
            if locationRegion.type == .Exit {
                print("TRACKER received enter but we are looking for exit, adding it to the inside list")
                self.insideCircularRegions.append(region.identifier)
                return;
            }
            
            let extendedRegion = CLCircularRegion(center: region.center, radius: locationRegion.radius + 1000, identifier: region.identifier)
            if let currentLocation = self.currentLocation(), !extendedRegion.contains(currentLocation.coordinate) {
                print("TRACKER false enter region - the region doesn't contain the current location \(self.locationCircularRegion(region: extendedRegion).debugDescription)")
                return
            }
            
            self.insideCircularRegions.append(region.identifier)
            self.notify(region: region, type: LocationCircularRegionType.Enter)
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let region = region as? CLCircularRegion,
            let locationRegion = locationCircularRegion(region: region) else {
                return
        }
        
        print("TRACKER received did exit region from iOS \(locationRegion)")
        self.forceLocationUpdate()

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.logRegion(circularRegion: region);
            
            if let locationRegion = self.locationCircularRegion(region: region), locationRegion.type == .Enter {
                self.insideCircularRegions = self.insideCircularRegions.filter( { $0 != region.identifier} )
                print("TRACKER received exit but it's enter, removing the region from the inside list")
                return;
            }
            
/*            if (!self.insideCircularRegions.contains(circularRegion.identifier)) {
                self.print("TRACKER false exit region - we are not inside this region \(self.locationCircularRegion(circularRegion).debugDescription)")
                return
            }
  */
            let reducedRegion = CLCircularRegion(center: region.center, radius: region.radius * 0.9, identifier: region.identifier)
            if let currentLocation = self.currentLocation(), reducedRegion.contains(currentLocation.coordinate) {
                print("TRACKER false exit region - we are still inside this region \(self.locationCircularRegion(region: reducedRegion).debugDescription)");
                return
            } else {
                let extendedRegion = CLCircularRegion(center: region.center, radius: region.radius + 1000, identifier: region.identifier)
                if let currentLocation = self.currentLocation(), !extendedRegion.contains(currentLocation.coordinate) {
                    print("TRACKER false exit region - we expected the exit to be within radius + 1000 meters \(self.locationCircularRegion(region: reducedRegion).debugDescription)")
                    return
                }
            }
            
            self.insideCircularRegions = self.insideCircularRegions.filter( { $0 != region.identifier} )
            self.notify(region: region, type: LocationCircularRegionType.Exit)
        }
    }
    
    func notify(region: CLRegion, type: LocationCircularRegionType) {
        if let locationRegion = locationCircularRegion(region: region) {
            print("TRACKER will publish notification for region \(locationRegion) - \(type.rawValue)")
            if let distanceFromCurrentLocation = self.manager.location?.distance(from: locationRegion.location()) {
                print("TRACKER Received \(type.rawValue) notification while being \(distanceFromCurrentLocation) from the last known location")
            }
            if (type == LocationCircularRegionType.Enter) {
                self.delegate.didEnterRegion(region: locationRegion)
            } else {
                self.delegate.didEnterRegion(region: locationRegion)
            }
        }
        self.reloadGeoFenceLocations()
    }
    
    public func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        if let region = region, let locationRegion = self.locationCircularRegion(region: region) {
            print("Monitoring for region \(locationRegion.note) failed")
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if (status != CLAuthorizationStatus.authorizedAlways) {
            if let errorMessage = self.locationTrackingStatus() {
                print("Location authorization failed with: '\(errorMessage)'")
            }
        }
    }
    
    func locationTrackingStatus() -> String? {
        switch CLLocationManager.authorizationStatus() {
        case CLAuthorizationStatus.authorizedAlways:
            break
        case CLAuthorizationStatus.authorizedWhenInUse:
            return "App is not allowed to use location services in background";
        case CLAuthorizationStatus.notDetermined:
            return "App is not allowed to use location services yet";
        case CLAuthorizationStatus.denied:
            return "App is not allowed to use location services";
        case CLAuthorizationStatus.restricted:
            return "App use of location services is restricted";
        }
        if (!CLLocationManager.locationServicesEnabled()) {
            return "Location services are not enabled";
        }
        
        return nil
    }

    func forceLocationUpdate() {
        self.manager.stopUpdatingLocation()
        self.manager.startUpdatingLocation()
    }
    
    
    func locationCircularRegion(region:CLRegion) -> LocationCircularRegion? {
        return locationsToTrack.filter({ $0.identifier == region.identifier}).first
    }
    
    func logRegion(circularRegion: CLCircularRegion) {
        if let currentLocation = currentLocation(), let regionToTrack = locationCircularRegion(region: circularRegion) {
            print("TRACKER distance from current location:\(currentLocation.distance(from: regionToTrack.location())) radius:\(circularRegion.radius) region:\(regionToTrack.debugDescription)")
        }
    }
}
