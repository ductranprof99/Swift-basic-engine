//
//  LocationServiceManager.swift
//  MetaServices
//
//  Created by DucTran on 22/02/2023.
//

import Foundation
import CoreLocation


public class LocationServiceManager {
    @objc public weak var delegate: LocationServiceDelegate?
    
    private let fixedService = FixedLocationService()
    private var isGPSAuthorize: Bool = false
    private var trackingQueue: DispatchQueue = .init(label: "com.location.trackingQueue")
    private var isStillTracking = false
    
    public static var share = LocationServiceManager()
    
    public init(delegate: LocationServiceDelegate? = nil) {
        self.delegate = delegate
        self.requestGPSAuthorizeInit()
    }
    
    private func requestGPSAuthorizeInit() {
        do {
            if #available(iOS 14.0, *) {
                try InovateGPSLocationService.shared.checkLocationAuthorization()
            } else {
                try LegacyGPSLocationService.shared.checkLocationAuthorization()
            }
            isGPSAuthorize = true
        } catch {
            print("Location service currently unavailable")
        }
    }
}
    
extension LocationServiceManager {
    
    public func locationDistance() -> Double {
        return 0.0
    }
    
    public func stopService() {
        if #available(iOS 14.0, *) {
            InovateGPSLocationService.shared.stopTask()
        } else {
            LegacyGPSLocationService.shared.stopTask()
        }
        trackingQueue.async {
            self.isStillTracking = false
        }
    }
    
    public func getAvailableLocation(isGPS: Bool) {
        isStillTracking = true
        if isGPS {
            if #available(iOS 14.0, *) {
                Task.init() {
                    do {
                        while(trackingQueue.sync{isStillTracking}) {
                            let coord = try await InovateGPSLocationService
                                                            .shared
                                                            .forceUpdatedLocation()
                            delegate?.currentGPSLocation?(coordinate: coord)
                            sleep(10)
                        }
                    } catch GPSError.currentLocationUnavailable {
                        requestGPSAuthorization()
                    } catch {
                        print("Error in get available location: location service manager: " + error.localizedDescription)
                    }
                }
            } else {
                let anotherQueue = DispatchQueue(label: "com.example.tracking")
                anotherQueue.async { [unowned self] in
                    while(self.trackingQueue.sync{self.isStillTracking}) {
                        LegacyGPSLocationService.shared.getCurrentLocationLegacy { [weak self] result in
                            if case let .success(coord) = result {
                                self?.delegate?.currentGPSLocation?(coordinate: coord)
                            }
                        }
                        sleep(10)
                    }
                }
            }
        } else {
            do {
                let address = try fixedService.getCurrentLocation()
                delegate?.currentStringLocation?(address: address)
            } catch FixedLocationError.savedLocationNotAvaiable {
                delegate?.addressLocationInput?()
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    public func updateLocation(isGPS: Bool,
                               address: String? = nil) {
        if isGPS {
            if #available(iOS 14.0, *) {
                Task() {
                    _ = try? await InovateGPSLocationService.shared.forceUpdatedLocation()
                }
            } else {
                try? LegacyGPSLocationService.shared.updateLocation()
            }
            self.stopService()
        } else {
            guard let address = address else {
                print("Update fixed location require address parameter")
                return
            }
            fixedService.updateCurrentLocation(address: address)
            delegate?.currentStringLocation?(address: address)
        }
    }
    
    public func requestGPSAuthorization() {
        do {
            if #available(iOS 14.0, *) {
                try InovateGPSLocationService.shared.checkLocationAuthorization()
            } else {
                try LegacyGPSLocationService.shared.checkLocationAuthorization()
            }
            isGPSAuthorize = true
            delegate?.locationGPSAuthorization?(isAuthorized: true, isAcceptAuthorize: true)
        } catch GPSError.authorizationDeniedOrRestricted {
            delegate?.locationGPSAuthorization?(isAuthorized: false, isAcceptAuthorize: false)
        } catch GPSError.authorizationNotDetermined {
            delegate?.locationGPSAuthorization?(isAuthorized: false, isAcceptAuthorize: true)
        } catch GPSError.unknownAuthorizationStatus {
            delegate?.locationGPSAuthorization?(isAuthorized: false, isAcceptAuthorize: true)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    public func turnOnGPSBackgroundMode() {
        if #available(iOS 14.0, *) {
            InovateGPSLocationService.shared.turnOnLocationBackgroundMode()
        } else {
            LegacyGPSLocationService.shared.turnOnLocationBackgroundMode()
        }
    }
    
    public func turnOffGPSBackgroundMode() {
        if #available(iOS 14.0, *) {
            InovateGPSLocationService.shared.turnOffLocationBackgroundMode()
        } else {
            LegacyGPSLocationService.shared.turnOffLocationBackgroundMode()
        }
    }
}
