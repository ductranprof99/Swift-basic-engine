//
//  BasicAudioEngine.swift
//  MetaServices
//
//  Created by DucTran on 20/02/2023.
//
import AVFoundation
import MetaUltility

enum BasicEngineError: Error {
    case couldNotCreateInputNode
    case couldNotConvertStreamBuffer
    case tempFileNotExits
}

final class BasicAudioEngine {
    
    private let engine = AVAudioEngine()
    
    
    // MARK: Streaming property
    private var isStreaming = false
    

    // MARK: Record file property
    private let tempFileURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("temp.caf")
    private let autoSaveAudioURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("autosave.caf")
    private var isRecording = false
    private var isAutoSave = false
    private let dispachGuardAutoSaveVar = DispatchQueue(label: "audio.basicEngine.guardvar.autoSave")
    
    
    // MARK: Player property
    private var isPlaying = false
    private var player = AVAudioPlayerNode()
    private var currentPlayBuffer: AVAudioPCMBuffer?
    private var nextPlayBuffer: AVAudioPCMBuffer?
    private var previousPlayBuffer: AVAudioPCMBuffer?
    
    
    // MARK: MixerNode (for custom sound)
    private let volumeMixer = AVAudioMixerNode()
    private let pitchMixer = AVAudioMixerNode()
    private let speedMixer = AVAudioMixerNode()
    private let distortionEffect = AVAudioUnitDistortion()
    
}
 
// MARK: - For player
extension BasicAudioEngine {
    
    private func setupPlayer() {
        engine.attach(player)
        engine.attach(volumeMixer)
        engine.attach(pitchMixer)
        engine.attach(speedMixer)
        engine.attach(distortionEffect)
        
        engine.connect(player, to: volumeMixer, format: nil)
        engine.connect(volumeMixer, to: pitchMixer, format: nil)
        engine.connect(pitchMixer, to: speedMixer, format: nil)
        engine.connect(speedMixer, to: engine.mainMixerNode, format: nil)
        engine.connect(distortionEffect, to: pitchMixer, format: nil)
        
        engine.prepare()
        do {
            try engine.start()
        } catch {
            print(error.localizedDescription)
            print("player engine cannot start")
        }
    }
    
    private func detachPlayer() {
        engine.detach(player)
        engine.detach(volumeMixer)
        engine.detach(pitchMixer)
        engine.detach(speedMixer)
        engine.detach(distortionEffect)
    }
    
    // MARK: Basic player function
    
    // TODO: Fix play mechanism, no sound after second play
    func startPlaying(url: URL)  {
        if isPlaying { return }
        isPlaying = true
        stopRecording()
        stopStreaming()
        setupPlayer()
        do {
            let file = try AVAudioFile(forReading: url)
            let sampleRate = file.processingFormat.sampleRate
            let segmentTime : AVAudioFramePosition = 0
            player.scheduleFile(file, at: AVAudioTime(sampleTime: segmentTime, atRate: sampleRate), completionHandler: nil)
            player.play()
        } catch {
            print(error.localizedDescription)
            stopPlaying()
        }
    }
    
    // TODO: Fix play mechanism, right way terminate but wrong mechanism for replay
    func stopPlaying() {
        if !isPlaying { return }
        player.stop()
        engine.stop()
        engine.reset()
        detachPlayer()
        isPlaying = false
        currentPlayBuffer = nil
        nextPlayBuffer = nil
        previousPlayBuffer = nil
    }
    
    func pause() {
        engine.pause()
    }
    
    // TODO: Implement
    func forwardTime(for timeStamp: Double) {
        
    }
    
    // TODO: Implement
    func backwardTime(for timeStamp: Double) {
        
    }
    
    // TODO: Implement
    func nextAudio(url: URL) {
        
    }
    
    // TODO: Implement
    func previousAudio(url: URL) {
        
    }
    
    // TODO: Implement
    func volumeUp() {
        volumeMixer.outputVolume += 0.1
    }
    
    // TODO: Implement
    func volumeDown() {
        volumeMixer.outputVolume -= 0.1
    }
    
    // MARK: Advance player function
    func createSoundFromLiveData(with buffer: AVAudioPCMBuffer) {
        
    }
    
    func createSoundFromStreamedData(data: [Data]) {
        
    }
}

// MARK: For recording
extension BasicAudioEngine {
    
    private func setupRecorder() {
        let file: AVAudioFile
        do {
            file = try AVAudioFile(forWriting: tempFileURL, settings: engine.inputNode.outputFormat(forBus: 1).settings)
        } catch {
            print("set up recorder fail")
            print("Error: \(error)")
            return
        }
        engine.inputNode.installTap(onBus: 1, bufferSize: 4096, format: engine.inputNode.outputFormat(forBus: 1)) { (buffer, time) -> Void in
            do {
                try file.write(from: buffer)
            } catch {
                print("Error: \(error)")
            }
        }
    }
    
    func startRecording(isAutoSave: Bool = false, timeStamp: UInt32 = 10) {
        if engine.isRunning && isRecording { return }
        isRecording = true
        stopStreaming()
        stopPlaying()
        setupRecorder()
        engine.prepare()
        autoSaveFile(isEnable: isAutoSave, timeStamp: timeStamp)
        do {
            // Start engine
            try engine.start()
        } catch {
            print("Error: \(error)")
        }
    }
    // TODO: Audio files cannot be non-interleaved. Ignoring setting AVLinearPCMIsNonInterleaved YES.
    func stopRecording() {
        if !engine.isRunning { return }
        if isRecording {
            isRecording = false
            engine.inputNode.removeTap(onBus: 1)
            engine.stop()
        }
    }
    
    private func autoSaveFile(isEnable: Bool, timeStamp: UInt32 = 1) {
        dispachGuardAutoSaveVar.async { [weak self] in
            self?.isAutoSave = isEnable
        }
        while dispachGuardAutoSaveVar.sync(execute: {isAutoSave}) {
            if isRecording {
                dispachGuardAutoSaveVar.async { [weak self] in
                    guard let self = self else { return }
                    do {
                        try self.saveToFile(url: self.autoSaveAudioURL)
                    } catch {
                        print("Cannot save file")
                    }
                }
                sleep(timeStamp)
            }
        }
    }
    
    func saveToFile(url: URL) throws {
        guard FileManager.default.fileExists(atPath: tempFileURL.path) else {
            print("temporary data not exist")
            throw BasicEngineError.tempFileNotExits
        }
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                print("ogirin file exist")
                try FileManager.default.removeItem(at: url)
                print("origin file remove")
            }
        } catch {
            print("cannot remove save file location")
        }
        try FileManager.default.copyItem(at: tempFileURL, to: url)
        print("Save file success")
        do {
            try FileManager.default.removeItem(at: tempFileURL)
            print("temp file removed")
        } catch {
            print("cannot delete temp file, remove at next launch")
        }
    }
    
    func getFileFromPreviousAutoSave() -> AVAudioPCMBuffer? {
        guard FileManager.default.fileExists(atPath: autoSaveAudioURL.path) else {
            return nil
        }
        
        do {
            let audioFile = try AVAudioFile(forReading: autoSaveAudioURL)
            let audioFormat = audioFile.processingFormat
            let audioFrameCount = UInt32(audioFile.length)
            guard let audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: audioFrameCount) else {
                return nil
            }
            
            try audioFile.read(into: audioBuffer)
            return audioBuffer
            
        } catch {
            print("Error: \(error)")
            return nil
        }
    }
}


// MARK: - For streaming
extension BasicAudioEngine {
    
    private func setupStreaming(completion: @escaping ((AVAudioPCMBuffer, AVAudioTime) -> Void)) {
        let outputFormat = engine.inputNode.outputFormat(forBus: 0)
        engine
            .inputNode
            .installTap(onBus: 0,
                        bufferSize: 4096,
                        format: outputFormat) { (buffer, time) -> Void in
                completion(buffer,time)
            }
    }

    func startStreaming(completion: @escaping ((AVAudioPCMBuffer, AVAudioTime) -> Void)) {
        if engine.isRunning && isStreaming { return }
        isStreaming = true
        stopRecording()
        stopPlaying()
        setupStreaming(completion: completion)
        engine.prepare()
        do {
            // Start engine
            try engine.start()
        } catch {
            print("Error: \(error)")
        }
    }
    
    func stopStreaming() {
        if !engine.isRunning { return }
        if isStreaming {
            isStreaming = false
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
    }
    
}
