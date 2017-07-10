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
    var resolution: String?   // for setting photo resolution (use constants "AVCaptureSessionPreset...")
    var photoBracketExposures: [Double]?   // optional b/c only used for bracketed photo sequences -> in seconds
                                            // implicitly contains number of photos in bracket (= # items in array)
    var pointOfFocus: CGPoint?  // point of focus: represents where to focus in field of view
    var torchMode: AVCaptureTorchMode?
    var torchLevel: Float?
    var lensPosition: Float?
    
    var binaryCodeSystem: BinaryCodeSystem?
    var binaryCodeDirection: Bool?
    var binaryCodeBit: Int?         // bit of binary code being displayed
    var binaryCodeInverted: Bool?   // if binary code is inverted
    
    //MARK: Initialization
    
    // for decoding packet
    required convenience init?(coder decoder: NSCoder) {
        self.init()
        self.cameraInstruction = CameraInstruction(rawValue: decoder.decodeInteger(forKey: "cameraInstruction"))
        self.resolution = decoder.decodeObject(forKey: "captureSessionPreset") as! String!
        self.photoBracketExposures = decoder.decodeObject(forKey: "photoBracketExposures") as! [Double]?
        self.pointOfFocus = decoder.decodeObject(forKey: "pointOfFocus") as! CGPoint?
        if let torchModeRaw = decoder.decodeObject(forKey: "torchMode") as! Int? {
            self.torchMode = AVCaptureTorchMode(rawValue: torchModeRaw)
        } else {
            self.torchMode = nil
        }
        self.torchLevel = decoder.decodeObject(forKey: "torchLevel") as! Float?
        self.lensPosition = decoder.decodeObject(forKey: "lensPosition") as! Float?
        
        if let binaryCodeSystemRaw = decoder.decodeObject(forKey: "binaryCodeSystem") as! Int? {
            self.binaryCodeSystem = BinaryCodeSystem(rawValue: binaryCodeSystemRaw)
        } else {
            self.binaryCodeSystem = nil
        }
        self.binaryCodeBit = decoder.decodeObject(forKey: "binaryCodeBit") as! Int?
        self.binaryCodeInverted = decoder.decodeObject(forKey: "binaryCodeInverted") as! Bool?
        self.binaryCodeDirection = decoder.decodeObject(forKey: "binaryCodeDirection") as! Bool?
    }
    
    // for standard initialization
    convenience init(cameraInstruction: CameraInstruction, resolution: String? = nil, photoBracketExposures: [Double]? = nil, pointOfFocus: CGPoint? = nil, torchMode: AVCaptureTorchMode? = nil, torchLevel: Float? = nil, lensPosition: Float? = nil, binaryCodeBit: Int? = nil, binaryCodeDirection: Bool? = nil, binaryCodeInverted: Bool? = nil, binaryCodeSystem: BinaryCodeSystem? = nil) {
        self.init()
        self.cameraInstruction = cameraInstruction
        self.resolution = resolution
        self.photoBracketExposures = photoBracketExposures
        self.pointOfFocus = pointOfFocus
        self.torchMode = torchMode
        self.torchLevel = torchLevel
        self.lensPosition = lensPosition
        
        self.binaryCodeBit = binaryCodeBit
        self.binaryCodeDirection = binaryCodeDirection
        self.binaryCodeInverted = binaryCodeInverted
        self.binaryCodeSystem = binaryCodeSystem
    }
    
    //MARK: Encoding/decoding
    func encode(with coder: NSCoder) {
        coder.encode(self.cameraInstruction.rawValue, forKey: "cameraInstruction")
        coder.encode(self.resolution, forKey: "captureSessionPreset")
        coder.encode(self.photoBracketExposures, forKey: "photoBracketExposures")
        coder.encode(self.pointOfFocus, forKey: "pointOfFocus")
        coder.encode(self.torchMode?.rawValue ?? nil, forKey: "torchMode")  // encodes optional Int
        coder.encode(self.torchLevel, forKey: "torchLevel")
        coder.encode(self.lensPosition, forKey: "lensPosition")
        
        coder.encode(self.binaryCodeSystem?.rawValue ?? nil, forKey: "binaryCodeSystem")
        coder.encode(self.binaryCodeBit, forKey: "binaryCodeBit")
        coder.encode(self.binaryCodeInverted, forKey: "binaryCodeInverted")
        coder.encode(self.binaryCodeDirection, forKey: "binaryCodeDirection")
    }
    
}

enum CameraInstruction: Int {
    case SetLensPosition, GetLensPosition, LockLensPosition
    case SetPointOfFocus
    case LockWhiteBalance, AutoWhiteBalance
    case LockExposure, AutoExposure
    case CaptureStillImage
    case CapturePhotoBracket
    case CaptureNormalInvertedPair, FinishCapturePair
    case StartStructuredLightingCaptureFull, EndStructuredLightingCaptureFull
    case EndCaptureSession
}

