//
//  ScreenRecorderManager.swift
//  MetaServices
//
//  Created by DucTran on 25/02/2023.
//

import Foundation

public class ScreenRecorderManager {
    private let recorder = ScreenRecorder()
    private var isRecording = false
    
    private let serviceDispatcher = DispatchQueue(label: "service.screenRecorder")
    public static let shared = ScreenRecorderManager()
    
    public func startRecording(isEnableMic:Bool) {
        if !isRecording {
            isRecording = true
            serviceDispatcher.async { [weak self] in
                try? self?.recorder.startRecording(isMicEnable: isEnableMic)
            }
        }
    }
    
    public func stopRecordingAndSaveToLibrary() {
        if ( serviceDispatcher.sync  {isRecording} ) {
            isRecording = false
            try? recorder.stopRecording(savePath: nil, isSaveToLibrary: true)
        }
    }
    
    public func stopRecordingAndSaveToFile(fileName: String) {
        if ( serviceDispatcher.sync  {isRecording} ) {
            isRecording = false
            let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
            let fileURL = URL(fileURLWithPath: documentsPath.appendingPathComponent("temp.mp4"))
            try? recorder.stopRecording(savePath: fileURL)
        }
    }
}

