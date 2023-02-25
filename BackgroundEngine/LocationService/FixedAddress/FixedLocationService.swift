//
//  MapService.swift
//  MetaServices
//
//  Created by DucTran on 18/02/2023.
//

import Foundation

enum FixedLocationError: Error {
    case savedLocationNotAvaiable
}

final class FixedLocationService {
    var locationString: String?
    
    func getCurrentLocation() throws -> String {
        if let locationString = locationString {
            return locationString
        }
        throw FixedLocationError.savedLocationNotAvaiable
    }
    
    func updateCurrentLocation(address: String) {
        locationString = address
    }
}
