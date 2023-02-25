//
//  CameraDelegate.swift
//  UIComponents
//
//  Created by DucTran on 17/02/2023.
//

import Foundation
import UIKit
import AVFoundation


enum CameraError: Error {
    case captureDeviceNotFound
    case configurationFailed
    case imageCreationFailed
}

@objc public
protocol CameraCaptureDelegate {
    func captureVideoOutput(sampleBuffer: CMSampleBuffer)
    @objc optional func captureAudioOutput(sampleBuffer: CMSampleBuffer)
}


final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (UIImage?, Error?) -> Void
    
    init(completion: @escaping (UIImage?, Error?) -> Void) {
        self.completion = completion
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            completion(nil, error)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(), let image = UIImage(data: imageData) else {
            completion(nil, CameraError.imageCreationFailed)
            return
        }
        
        completion(image, nil)
    }
}


