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
    var pointOfFocus: CGPoint?  // point of focus: represents where to focus in field of view
    var torchMode: AVCaptureTorchMode?
    var torchLevel: Float?
    
    //MARK: Initialization
    
    // for decoding packet
    required convenience init?(coder decoder: NSCoder) {
        self.init()
        self.cameraInstruction = CameraInstruction(rawValue: decoder.decodeInteger(forKey: "cameraInstruction"))
        self.captureSessionPreset = decoder.decodeObject(forKey: "captureSessionPreset") as! String!
        self.photoBracketExposures = decoder.decodeObject(forKey: "photoBracketExposures") as! [Double]?
        self.pointOfFocus = decoder.decodeObject(forKey: "pointOfFocus") as! CGPoint?
        if let torchModeRaw = decoder.decodeObject(forKey: "torchMode") as! Int? {
            self.torchMode = AVCaptureTorchMode(rawValue: torchModeRaw)
        } else {
            self.torchMode = nil
        }
        self.torchLevel = decoder.decodeObject(forKey: "torchLevel") as! Float?
    }
    
    // for standard initialization
    convenience init(cameraInstruction: CameraInstruction, captureSessionPreset: String = AVCaptureSessionPresetPhoto, photoBracketExposures: [Double]? = nil, pointOfFocus: CGPoint? = nil, torchMode: AVCaptureTorchMode? = nil, torchLevel: Float? = nil) {
        self.init()
        self.cameraInstruction = cameraInstruction
        self.captureSessionPreset = captureSessionPreset
        self.photoBracketExposures = photoBracketExposures
        self.pointOfFocus = pointOfFocus
        self.torchMode = torchMode
        self.torchLevel = torchLevel
    }
    
    //MARK: Encoding/decoding
    func encode(with coder: NSCoder) {
        coder.encode(self.cameraInstruction.rawValue, forKey: "cameraInstruction")
        coder.encode(self.captureSessionPreset, forKey: "captureSessionPreset")
        coder.encode(self.photoBracketExposures, forKey: "photoBracketExposures")
        coder.encode(self.pointOfFocus, forKey: "pointOfFocus")
        //coder.encode(self.torchMode, forKey: "torchMode")
        coder.encode(self.torchMode?.rawValue ?? nil, forKey: "torchMode")  // encodes optional Int
        coder.encode(self.torchLevel, forKey: "torchLevel")
    }
    
}

enum CameraInstruction: Int {
    case CaptureStillImage
    case CapturePhotoBracket
    case EndCaptureSession
}

