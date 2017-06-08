//
//  LocationTracker.swift
//  LocationGeofence
//
//  Created by Ciprian Rarau on 06/07/2017.
//  Copyright (c) 2017 Ciprian Rarau. All rights reserved.
//


import UIKit
import MapKit
import UserNotifications
import SwiftyJSON

extension JSON {
    public var prettyString: String {
        return self.rawString()!
    }
}


extension UIViewController {
    func loadLocations() -> Array<LocationCircularRegion> {
        guard let locationsPref = UserDefaults.standard.object(forKey: "places") as? String else{
            return []
        }
        
        return JSON.parse(locationsPref).arrayValue.map{LocationCircularRegion.from($0)}
    }

    func saveLocations(locations: Array<LocationCircularRegion>) {
        let locationString = JSON(locations.map{$0.toDict}).prettyString
        UserDefaults.standard.set(locationString, forKey: "places")
        UserDefaults.standard.synchronize()
        
        LocationGeofenceTracker.sharedInstance.reloadGeoFenceLocations()
    }
    
    func presentLocalNotification(region:LocationCircularRegion) {
        let name = region.note.isEmpty ? "Unamed": region.note
        let alertBody = "\(region.type.rawValue) - \(name)"
        
        if UIApplication.shared.applicationState == .active {
            UIAlertController.error(alertBody)
        } else {
            let content = UNMutableNotificationContent()
            content.title = name
            content.body = alertBody
            content.sound = UNNotificationSound.default()
            content.categoryIdentifier = "com.chip"
            let trigger = UNTimeIntervalNotificationTrigger.init(timeInterval: 0, repeats: false)
            let request = UNNotificationRequest.init(identifier: "Now", content: content, trigger: trigger)
            
            let center = UNUserNotificationCenter.current()
            center.add(request)
        }
    }
}


enum GeofenceEvent: String {
    case location = "location"
}

extension NotificationCenter {
    static func publish(_ event:GeofenceEvent) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name(rawValue: event.rawValue), object: nil);
        }
    }
    
    static func publish(_ event:GeofenceEvent, userInfo:[String:String]) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name(rawValue: event.rawValue), object: nil, userInfo: userInfo)
        }
    }
    
    static func observe(_ event:GeofenceEvent, block:@escaping ([String:String])->Void) {
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: event.rawValue), object: nil, queue: nil) { (notification) in
            DispatchQueue.main.async {
                guard let userInfo = notification.userInfo as? [String: String] else {
                    block([:])
                    return
                }
                block(userInfo)
            }
        }
    }
    
    static func removeObserver(_ observer:AnyObject) {
        NotificationCenter.default.removeObserver(observer)
    }
}

extension UIViewController {
    func removeFromObservers() {
        NotificationCenter.removeObserver(self)
    }
}


extension Array {
    func takeElements( elementCount: Int) -> Array {
        var elementCount = elementCount
        if (elementCount > count) {
            elementCount = count
        }
        return Array(self[0..<elementCount])
    }
}

extension CLLocation {
    func toDebugDescriptionString() -> String {
        return "coordinate \(self.coordinate.latitude),\(self.coordinate.longitude) horizontalAccuracy \(self.horizontalAccuracy) verticalAccuracy \(self.verticalAccuracy) timestamp:\(self.timestamp) received:\(NSDate().timeIntervalSince(self.timestamp))s ago"
    }
    
}



