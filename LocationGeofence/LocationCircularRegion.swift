//
//  LocationTracker.swift
//  LocationGeofence
//
//  Created by Ciprian Rarau on 06/07/2017.
//  Copyright (c) 2017 Ciprian Rarau. All rights reserved.
//


import Foundation
import CoreLocation
import SwiftyJSON

enum LocationCircularRegionType:String {
    case Enter = "Enter"
    case Exit = "Exit"
}

extension CLLocationCoordinate2D {
    var toDict:[String: Any] {
        return [
            "latitude": latitude,
            "longitude": longitude
        ]
    }
    
    static func from(_ json: JSON) -> CLLocationCoordinate2D {
        return CLLocationCoordinate2D(
            latitude: json["latitude"].doubleValue,
            longitude: json["longitude"].doubleValue
        )
    }
}

struct LocationCircularRegion {
    let identifier:String
    let coordinate:CLLocationCoordinate2D
    let radius:CLLocationDistance
    let type:LocationCircularRegionType
    let note:String
    
    func location() -> CLLocation {
        return CLLocation(latitude: self.coordinate.latitude, longitude: self.coordinate.longitude)
    }
    
    func region() -> CLCircularRegion {
        return CLCircularRegion(center: self.coordinate, radius: self.radius, identifier: self.identifier)
    }
    
    var debugDescription: String {
        get {
            return "identifier:\(self.identifier) coordinate:\(self.coordinate.latitude),\(self.coordinate.longitude) radius:\(self.radius) type:\(self.type.rawValue) note:\(self.note)"
        }
    }
    
    var toDict:[String: Any] {
        return [
            "identifier": identifier,
            "coordinate": coordinate.toDict,
            "radius": radius,
            "type": type.rawValue,
            "note": note
        ]
    }
    
    static func from(_ json: JSON) -> LocationCircularRegion {
        return LocationCircularRegion(
            identifier: json["identifier"].stringValue,
            coordinate: CLLocationCoordinate2D.from(json["coordinate"]) ,
            radius: json["radius"].doubleValue,
            type: LocationCircularRegionType.init(rawValue: json["type"].stringValue) ?? .Enter,
            note: json["note"].stringValue
        )
    }
}
