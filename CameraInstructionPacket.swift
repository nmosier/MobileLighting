//
//  CameraInstructionPacket.swift
//  
//
//  Created by Nicholas Mosier on 5/25/17.
//
//

import Foundation
import AVFoundation

@objc(CameraInstructionPacket)
class CameraInstructionPacket: NSObject, NSCoding {
    var cameraInstruction: CameraInstruction!
    var captureSessionPreset: String!
    
    //MARK: Initialization
    
    // for decoding packet
    required convenience init?(coder decoder: NSCoder) {
        self.init()
        self.cameraInstruction = CameraInstruction(rawValue: decoder.decodeInteger(forKey: "cameraInstruction"))
        self.captureSessionPreset = decoder.decodeObject(forKey: "captureSessionPreset") as! String!
        
    }
    
    // for standard intiialization
    convenience init(cameraInstruction: CameraInstruction, captureSessionPreset: String = AVCaptureSessionPresetPhoto) {
        self.init()
        self.cameraInstruction = cameraInstruction
        self.captureSessionPreset = captureSessionPreset
    }
    
    //MARK: Encoding/decoding
    func encode(with coder: NSCoder) {
        coder.encode(self.cameraInstruction.rawValue, forKey: "cameraInstruction")
        coder.encode(self.captureSessionPreset, forKey: "captureSessionPreset")
    }
    
}

enum CameraInstruction: Int {
    case CaptureStillImage, CapturePhotoBracket, EndCaptureSession
}

