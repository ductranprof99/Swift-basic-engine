//
//  ScreenRecorder.swift
//  MetaServices
//
//  Created by DucTran on 25/02/2023.
//

import Foundation
import AVFoundation
import ReplayKit
import Photos

public enum ScreenRecordError: Error {
    case capturingScreenError
    case photoLibraryNotGrantAccess
    case stopCaptureError
}

final class ScreenRecorder {
    
    private let recorder = RPScreenRecorder.shared()

    private var videoWriter: AVAssetWriter?
    private var videoWriterInput: AVAssetWriterInput?
    private var micAudioWriterInput: AVAssetWriterInput
    private var appAudioWriterInput: AVAssetWriterInput
    private var passingSize: CGSize = UIScreen.main.bounds.size
    private var tempPath: URL?
    
    init() {
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        self.appAudioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
        self.micAudioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
    }
}

// MARK: - Basic public Ultility
extension ScreenRecorder {
    private func startCapture(errorHandler: @escaping (NSError) -> Void) {
        recorder.startCapture(handler: { (sampleBuffer, sampleType, passedError) in
            if let passedError = passedError as? NSError {
                errorHandler(passedError)
                return
            }
            
            switch sampleType {
            case .video:
                self.handleSampleBuffer(sampleBuffer: sampleBuffer)
            case .audioApp:
                self.add(sample: sampleBuffer, to: self.appAudioWriterInput)
            case .audioMic:
                self.add(sample: sampleBuffer, to: self.micAudioWriterInput)
            default:
                break
            }
        })
    }
    
    private func createVideoWriter(error: (NSError) -> Void) {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
        let newVideoOutputURL = URL(fileURLWithPath: documentsPath.appendingPathComponent("temp.mp4"))
        tempPath = newVideoOutputURL
        do {
            try FileManager.default.removeItem(at: newVideoOutputURL)
        } catch {}
        
        do {
            try videoWriter = AVAssetWriter(outputURL: newVideoOutputURL, fileType: AVFileType.mp4)
        } catch let writerError as NSError {
            error(writerError)
            videoWriter = nil
            return
        }
    }
    
    private func handleSampleBuffer(sampleBuffer: CMSampleBuffer) {
        if self.videoWriter?.status == AVAssetWriter.Status.unknown {
            self.videoWriter?.startWriting()
            self.videoWriter?.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        } else if self.videoWriter?.status == AVAssetWriter.Status.writing &&
                    self.videoWriterInput?.isReadyForMoreMediaData == true {
            self.videoWriterInput?.append(sampleBuffer)
        }
    }
    
    private func addAudioInput() {
        videoWriter?.add(self.appAudioWriterInput)
        videoWriter?.add(self.micAudioWriterInput)
    }
    
    private func addVideoWriterInput(size: CGSize? = nil) {
        if let passSize = size {
            self.passingSize = passSize
        }
        let videoSettings: [String: Any] = [AVVideoCodecKey: AVVideoCodecType.h264,
                                            AVVideoWidthKey: passingSize.width,
                                           AVVideoHeightKey: passingSize.height]
        
        let newVideoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)
        self.videoWriterInput = newVideoWriterInput
        newVideoWriterInput.expectsMediaDataInRealTime = true
        videoWriter?.add(newVideoWriterInput)
    }
    
    private func add(sample: CMSampleBuffer, to writerInput: AVAssetWriterInput?) {
        if writerInput?.isReadyForMoreMediaData ?? false {
            writerInput?.append(sample)
        }
    }
    
    private func askPermissionAndSave() throws {
        var errorCatcher: Error? = nil
        if PHPhotoLibrary.authorizationStatus() == .authorized {
            saveVideoToLibrary()
        } else {
            PHPhotoLibrary.requestAuthorization { [weak self] (status) in
                if status == .authorized {
                    self?.saveVideoToLibrary()
                } else {
                    errorCatcher = ScreenRecordError.photoLibraryNotGrantAccess
                }
            }
        }
        if errorCatcher != nil { throw errorCatcher! }
    }
    
    private func saveVideoToLibrary() {
        guard let destination = tempPath else {
            print("Cannot save to camera roll: No temp file")
            return
        }
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: destination)
        }, completionHandler: { _, error in
            if let error = error {
                print("Cannot save to camera roll: " + error.localizedDescription)
            }
        })
    }
    
    private func saveVideoToPath(to path: URL?) throws {
        guard let destination = path, let source = tempPath else {
            print("Cannot save to camera roll: No temp file")
            return
        }
        try FileManager.default.copyItem(at: source, to: destination)
        print("Save file success")
    }
    
    private func deleteTempFile() {
        guard let tempPath = tempPath else { return }
        if FileManager.default.fileExists(atPath: tempPath.path) {
            do {
                try FileManager.default.removeItem(at: tempPath)
                print("Screen recorder: Cannot remove temp file")
            } catch {
                print("Screen recorder: Cannot remove temp file")
            }
        }
    }
}

// MARK: - Basic public Ultility
extension ScreenRecorder {
    public func startRecording(size: CGSize? = nil,
                               isMicEnable: Bool = false) throws {
        var errorCatcher: NSError? = nil
        recorder.isMicrophoneEnabled = isMicEnable
        createVideoWriter { error in
            print("Error when create video writer: " + error.localizedDescription)
            errorCatcher = error
        }
        addVideoWriterInput(size: size)
        addAudioInput()
        startCapture { error in
            print("Error when capturing: " + error.localizedDescription)
            errorCatcher = error
        }
        if errorCatcher != nil {
            throw ScreenRecordError.capturingScreenError
        }
    }
    
    public func stopRecording(savePath: URL? = nil, isSaveToLibrary: Bool = false) throws {
        var errorCatcher: Error? = nil
        recorder.stopCapture( handler: { error in
            print(error?.localizedDescription ?? "Stop success")
            errorCatcher = error
        })
        self.videoWriterInput?.markAsFinished()
        self.micAudioWriterInput.markAsFinished()
        self.appAudioWriterInput.markAsFinished()
        self.videoWriter?.finishWriting {
            do {
                if isSaveToLibrary {
                    try self.askPermissionAndSave()
                }
                if let savePath = savePath {
                    try self.saveVideoToPath(to: savePath)
                }
            } catch {
                errorCatcher = error
            }
        }
        if errorCatcher != nil {  throw errorCatcher! }
    }
    
    public func retrieveTemporaryFile() -> URL? {
        return self.tempPath
    }
}

