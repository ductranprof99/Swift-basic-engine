//
//  InovateGPSLocationService.swift
//  MetaServices
//
//  Created by DucTran on 18/02/2023.
//

import Foundation
import CoreLocation

enum GPSError: Error {
    case cannotRetrieveLocation
    case currentLocationUnavailable
    case locationServiceUnavailable
    
    case authorizationNotDetermined
    case authorizationDeniedOrRestricted
    case unknownAuthorizationStatus
}

@available(iOS 14.0, *)
final class InovateGPSLocationService {
    
    var task: Task<CLLocationCoordinate2D, any Error>?
    private let locationManager = GPSLocationManager()
    private var currentLocation: CLLocationCoordinate2D?
    static let shared = InovateGPSLocationService()
    
    func checkLocationAuthorization() throws {
        let status = locationManager.locationManager.authorizationStatus
        
        switch status {
        case .notDetermined:
            // Request authorization
            locationManager.locationManager.requestWhenInUseAuthorization()
            throw GPSError.authorizationNotDetermined
        case .denied, .restricted:
            throw GPSError.authorizationDeniedOrRestricted
        case .authorizedWhenInUse, .authorizedAlways:
            print("Location authorization successful")
        @unknown default:
            throw GPSError.unknownAuthorizationStatus
        }
    }

    func startTask() async {
        locationManager.startUpdatingLocation()
    }

    func stopTask() {
        locationManager.stopUpdatingLocation()
        task?.cancel()
    }

    func forceUpdatedLocation() async throws -> CLLocationCoordinate2D {
        if let currentLocation = locationManager.currentLocation {
            self.currentLocation = currentLocation
            return currentLocation
        } else {
            do {
                let coord = try await getCurrentLocation()
                return coord
            } catch {
                NSLog("Error in inovate gps service forced update location")
                throw GPSError.cannotRetrieveLocation
            }
        }
    }
    
    func getCurrentLocation() async throws -> CLLocationCoordinate2D {
        await startTask()
        task = Task { () -> CLLocationCoordinate2D in
            
            while(true) {
                sleep(5)
                guard let currentLocation = locationManager.currentLocation else {
                    NSLog("Error in inovate gps service get current location")
                    throw GPSError.currentLocationUnavailable
                }
                self.currentLocation = currentLocation
                return currentLocation
            }
        }
        return try await task!.value
    }
}

// MARK: - Public service
@available(iOS 14.0, *)
extension InovateGPSLocationService {
    func turnOnLocationBackgroundMode() {
        locationManager.turnOnBackgroundMode()
    }
    
    func turnOffLocationBackgroundMode() {
        locationManager.turnOffBackgroundMode()
    }
}


