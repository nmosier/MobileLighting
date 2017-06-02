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
    var captureSessionPreset: String!   // for setting photo resolution (use constants "AVCaptureSessionPreset...")
    var photoBracketExposures: [Double]?   // optional b/c only used for bracketed photo sequences -> in seconds
                                            // implicitly contains number of photos in bracket (= # items in array)
    //MARK: Initialization
    
    // for decoding packet
    required convenience init?(coder decoder: NSCoder) {
        self.init()
        self.cameraInstruction = CameraInstruction(rawValue: decoder.decodeInteger(forKey: "cameraInstruction"))
        self.captureSessionPreset = decoder.decodeObject(forKey: "captureSessionPreset") as! String!
        self.photoBracketExposures = decoder.decodeObject(forKey: "photoBracketExposures") as! [Double]?
    }
    
    // for standard initialization
    convenience init(cameraInstruction: CameraInstruction, captureSessionPreset: String = AVCaptureSessionPresetPhoto, photoBracketExposures: [Double]? = nil) {
        self.init()
        self.cameraInstruction = cameraInstruction
        self.captureSessionPreset = captureSessionPreset
        self.photoBracketExposures = photoBracketExposures
    }
    
    //MARK: Encoding/decoding
    func encode(with coder: NSCoder) {
        coder.encode(self.cameraInstruction.rawValue, forKey: "cameraInstruction")
        coder.encode(self.captureSessionPreset, forKey: "captureSessionPreset")
        coder.encode(self.photoBracketExposures, forKey: "photoBracketExposures")
    }
    
}

enum CameraInstruction: Int {
    case CaptureStillImage
    case CapturePhotoBracket
    case EndCaptureSession
}

