//
//  CameraInstructionPacket.swift
//  
//
//  Created by Nicholas Mosier on 5/25/17.
//
//

import Foundation

@objc(CameraInstructionPacket)
class CameraInstructionPacket: NSObject, NSCoding {
    var cameraInstruction: CameraInstruction!
    
    //MARK: Initialization
    
    // for decoding packet
    required convenience init?(coder decoder: NSCoder) {
        self.init()
        let cameraInstruction = CameraInstruction(rawValue: decoder.decodeInteger(forKey: "cameraInstruction"))
        self.cameraInstruction = cameraInstruction
    }
    
    // for standard intiialization
    convenience init(cameraInstruction: CameraInstruction) {
        self.init()
        self.cameraInstruction = cameraInstruction
    }
    
    //MARK: Encoding/decoding
    func encode(with coder: NSCoder) {
        guard let thisCameraInstruction = self.cameraInstruction else {
            print("Failed to encode camera instruction.")
            return
        }
        coder.encode(thisCameraInstruction.rawValue, forKey: "cameraInstruction")
    }
    
}

enum CameraInstruction: Int {
    case CaptureStillImage, CapturePhotoBracket, EndCaptureSession
}

