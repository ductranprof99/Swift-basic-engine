//
//  CameraManager.swift
//  UIComponents
//
//  Created by DucTran on 17/02/2023.
//

import Foundation
import AVFoundation
import UIKit


/// If you want to use camera with resume interupt -> Wrap this manager funciton inside a session 
public class CameraManager: NSObject {
    
    // MARK: - Capture device
    private var captureDevice: AVCaptureDevice? {
        get {
            let discoverySession = AVCaptureDevice
                .DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInWideAngleCamera],
                                  mediaType: AVMediaType.video,
                                  position: .unspecified)
            
            let devices = discoverySession.devices
            
            if let curr = devices.first(where: { $0.position == .back && $0.deviceType == .builtInDualCamera }) {
                return curr
            }
            if let curr = devices.first(where: { $0.position == .back && $0.deviceType == .builtInWideAngleCamera }) {
                return curr
            }
            
            if let curr = devices.first(where: { $0.position == .front }) {
                return curr
            }
            return nil
        }
    }
    
    // MARK: - Image
    private let photoOutput = AVCapturePhotoOutput()
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    
    // MARK: - Video
    private let captureSession = AVCaptureSession()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let audioDataOutput = AVCaptureAudioDataOutput()
    
    // MARK: - Manager Variable
    private let dataOutputQueue = DispatchQueue(label: "VideoDataQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    private var currentCameraInput: AVCaptureInput?
    @objc public weak var delegate: CameraCaptureDelegate?
    private var isCapturing = false
    
    public func requestCameraAuthorization(completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                completion(granted)
            }
        default:
            completion(false)
        }
    }
}

extension CameraManager {
            
    func setupCamera(previewView: UIView,useMic: Bool) {
        guard let captureDevice = self.captureDevice ,
            let videoInput = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
            currentCameraInput = videoInput
        }
        
        // Add a video data output
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
            videoDataOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
            videoDataOutput.connection(with: .video)?.videoOrientation = .portrait
            videoDataOutput.connection(with: .video)?.automaticallyAdjustsVideoMirroring = false
            videoDataOutput.connection(with: .video)?.isVideoMirrored = true
        } else {
            debugPrint("Could not add video data output to the session")
        }
        
        guard useMic,
            let audio = AVCaptureDevice.default(for: .audio),
            let audioInput = try? AVCaptureDeviceInput(device: audio) else { return }
        
        if captureSession.canAddInput(audioInput) {
            captureSession.addInput(audioInput)
        }
        
        if captureSession.canAddOutput(audioDataOutput) {
            captureSession.addOutput(audioDataOutput)
            audioDataOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
        }
        
        // Configure preview layer
        let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer.videoGravity = .resizeAspectFill
        videoPreviewLayer.frame = previewView.bounds
        previewView.layer.addSublayer(videoPreviewLayer)
        self.videoPreviewLayer = videoPreviewLayer
    }
    
    func startCapture() {
        debugPrint("Capture Start!!")
        
        guard isCapturing == false else { return }
        isCapturing = true
        
        #if arch(arm64)
        captureSession.startRunning()
        #endif
    }
    
    func stopCapture() {
        debugPrint("Capture Ended!!")
        guard isCapturing == true else { return }
        isCapturing = false

        #if arch(arm64)
        captureSession.stopRunning()
        #endif
    }
}

// MARK: Switching Camera
extension CameraManager {
    func switchCamera() {
        #if arch(arm64)
        
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        
        let nextPosition = ((currentCameraInput as? AVCaptureDeviceInput)?.device.position == .front) ? AVCaptureDevice.Position.back : .front
        
        if let currentCameraInput = currentCameraInput {
            captureSession.removeInput(currentCameraInput)
        }
                
        if let newCamera = cameraDevice(position: nextPosition),
            let newVideoInput: AVCaptureDeviceInput = try? AVCaptureDeviceInput(device: newCamera),
            captureSession.canAddInput(newVideoInput) {

            captureSession.addInput(newVideoInput)
            currentCameraInput = newVideoInput
                    
            videoDataOutput.connection(with: .video)?.videoOrientation = .portrait
            videoDataOutput.connection(with: .video)?.automaticallyAdjustsVideoMirroring = false
            videoDataOutput.connection(with: .video)?.isVideoMirrored = nextPosition == .front
        }
                
        #endif
    }

    private func cameraDevice(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .unspecified)
        for device in discoverySession.devices where device.position == position {
            return device
        }

        return nil
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if connection == videoDataOutput.connection(with: .video) {
            delegate?.captureVideoOutput(sampleBuffer: sampleBuffer)
        } else if connection == audioDataOutput.connection(with: .audio) {
            delegate?.captureAudioOutput?(sampleBuffer: sampleBuffer)
        }
    }
    public func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    }
}

extension CameraManager {
    func takePicture(completion: @escaping (UIImage?, Error?) -> Void) {
        guard let captureDevice = captureDevice else {
            completion(nil, CameraError.captureDeviceNotFound)
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: captureDevice)
            if captureSession.canAddInput(input) && captureSession.canAddOutput(photoOutput) {
                captureSession.addInput(input)
                captureSession.addOutput(photoOutput)
                
                let settings = AVCapturePhotoSettings()
                photoOutput.capturePhoto(with: settings, delegate: PhotoCaptureDelegate(completion: completion))
            } else {
                completion(nil, CameraError.configurationFailed)
            }
        } catch {
            completion(nil, error)
        }
    }
}
