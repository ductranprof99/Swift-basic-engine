//
//  LegacyGPSLocationService.swift
//  MetaServices
//
//  Created by DucTran on 22/02/2023.
//

import Foundation
import CoreLocation

@available(iOS, introduced: 12.0, deprecated: 14.0, message: "This feature is only available on iOS 14.0 or newer.")
final class LegacyGPSLocationService {

    var dispatchQueue: DispatchQueue = .init(label: "gpsQueue")
    private let locationManager: GPSLocationManager = .init()
    private var currentLocation: CLLocationCoordinate2D?
    
    static let shared = LegacyGPSLocationService()
    
    func checkLocationAuthorization() throws {
        let status = CLLocationManager.authorizationStatus()
        
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
    
    func stopTask() {
        locationManager.stopUpdatingLocation()
    }
    
    func getCurrentLocationLegacy(completion: @escaping (Result<CLLocationCoordinate2D, Error>) -> Void) {
        if let currentLocation = locationManager.currentLocation {
            self.currentLocation = currentLocation
            completion(.success(currentLocation))
        } else {
            dispatchQueue.async { [weak self] in
                guard let self = self else { return }
                do {
                    try self.updateLocation()
                } catch {
                    completion(.failure(GPSError.cannotRetrieveLocation))
                }
            }
        }
    }


    func startTask(completion: @escaping () -> Void) throws {
        locationManager.startUpdatingLocation()
        dispatchQueue.asyncAfter(deadline: .now() + 5) { [weak self] in
            do {
                try self?.updateLocation()
                completion()
            } catch {
                completion()
                print("Cannot update location: \(error.localizedDescription)")
            }
        }
    }
    
    func updateLocation() throws {
        let group = DispatchGroup()
        group.enter()
        
        do {
            try self.startTask {
                group.leave()
            }
        } catch {
            throw GPSError.cannotRetrieveLocation
        }
        
        group.wait()
    }
}

extension LegacyGPSLocationService {
    func turnOnLocationBackgroundMode() {
        locationManager.turnOnBackgroundMode()
    }
    
    func turnOffLocationBackgroundMode() {
        locationManager.turnOffBackgroundMode()
    }
}
