//
//  AudioServiceDelegate.swift
//  MetaServices
//
//  Created by DucTran on 20/02/2023.
//

import Foundation

@objc public protocol AudioServiceDelegate {
    @objc optional func processAudioStreamData(data: Data)
}
