//
//  AudioServiceManager.swift
//  MetaServices
//
//  Created by DucTran on 20/02/2023.
//

import AVFoundation
import MetaUltility

enum AudioHardwareError: Error {
    case micAccessNotGranted
    case permissionDenied
    case permissionUndetermined
    case unknownError
}

public class AudioServiceManager {
    
    @objc public weak var delegate: AudioServiceDelegate?
    private var isGrantedAccess = false
    private var isRecording = false
    private var managerDispatch = DispatchQueue(label: "audio.manager.dispatch")
    private var engine = BasicAudioEngine()
    
    public static var shared: AudioServiceManager = .init()
    
    init() {
        self.requestRecordingPermission()
    }
}

// MARK: - Streamer part
extension AudioServiceManager {
    public func startStreaming() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [])
            try audioSession.setActive(true)
            let input = audioSession.availableInputs?.first(where: { $0.portType == .builtInMic })
            try audioSession.setPreferredInput(input)
        } catch {
            print("session error")
        }
        engine.startStreaming { [weak self] (buffer,timer) in
            let data = Data(with: buffer)
            self?.delegate?.processAudioStreamData?(data: data)
        }
    }
    
    public func stopStreaming() {
        engine.stopStreaming()
    }
}

// MARK: - Player part
extension AudioServiceManager {
    private func isFileExits(with fileName: String) -> URL? {
        let filePath = FileManager
                            .default
                            .urls(for: .documentDirectory,
                                  in: .userDomainMask).first!
                                                      .appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: filePath.absoluteString) else { return nil }
        return filePath
    }
    
    public func startPlay(with fileName: String) {
        let filePath = FileManager
                            .default
                            .urls(for: .documentDirectory,
                                  in: .userDomainMask).first!
                                                      .appendingPathComponent(fileName + ".caf")
        engine.startPlaying(url: filePath)
    }
    
    public func stopPlay() {
        engine.stopPlaying()
    }
}

// MARK: - Recorder part
extension AudioServiceManager {
    
    public func startRecording(isAutoSave: Bool = false, timeStamp: UInt32 = 10) {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [])
            try audioSession.setActive(true)
            let input = audioSession.availableInputs?.first(where: { $0.portType == .builtInMic })
            try audioSession.setPreferredInput(input)
        } catch {
            print("session error")
        }
        engine.startRecording(isAutoSave: isAutoSave, timeStamp: timeStamp)
    }
    
    public func stopRecording() {
        engine.stopRecording()
    }

    public func saveToAudioFile(with fileName: String) {
        let filePath = FileManager
                            .default
                            .urls(for: .documentDirectory,
                                  in: .userDomainMask).first!
                                                      .appendingPathComponent(fileName + ".caf")
        do {
            try engine.saveToFile(url: filePath)
        } catch {
            print("cannot save file in audio service manager")
            print(error.localizedDescription)
        }
    }
}

// MARK: - Permission part
extension AudioServiceManager {
    
    private func requestRecordingPermission() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            guard granted else {
                self?.isGrantedAccess = granted
                return
            }
        }
    }
}
