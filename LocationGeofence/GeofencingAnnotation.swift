//
//  GeofencingAnnotation.swift
//  LocationGeofence
//
//  Created by Ciprian Rarau on 06/07/2017.
//  Copyright (c) 2017 Ciprian Rarau. All rights reserved.
//

import Foundation
import MapKit

class GeofencingAnnotation: MKPointAnnotation {
    var region: LocationCircularRegion
    
    init(region: LocationCircularRegion) {
        self.region = region
        super.init()

        self.coordinate = region.coordinate
        self.title = region.note.isEmpty ? "Unamed" : region.note
    }
}
