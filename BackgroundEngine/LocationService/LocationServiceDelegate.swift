//
//  LocationServiceDelegate.swift
//  MetaServices
//
//  Created by DucTran on 18/02/2023.
//

import Foundation
import CoreLocation

@objc public protocol LocationServiceDelegate {
    @objc optional func locationGPSAuthorization(isAuthorized: Bool, isAcceptAuthorize: Bool)
    @objc optional func currentGPSLocation(coordinate: CLLocationCoordinate2D)
    
    @objc optional func addressLocationInput()
    @objc optional func currentStringLocation(address: String)
}
