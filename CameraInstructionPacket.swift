//
//  CameraInstructionPacket.swift
//  
//
//  Created by Nicholas Mosier on 5/25/17.
//
//

import Foundation
import AVFoundation

@objc(CameraInstruction)
// CameraInstruction: specifies type of instruction being sent to iPhone
enum CameraInstruction: Int {
    case SetLensPosition    // requires lensPosition parameter
    case GetLensPosition
    case LockLensPosition   // lensPosition parameter optional
    case SetPointOfFocus    // requires pointOfFocus parameter
    
    case LockExposure, AutoExposure // sets camera exposure mode
    
    case CaptureStillImage  // capture single image; optional parameters: resolution
    case CapturePhotoBracket    // capture photo bracket; required parameters:
                                //      photoBracketExposureDurations; optional parameters: resolution
    
    // the following instructions are used by captureWithStructuredLighting function in Mac app's
    //   ProgramControl.swift
    case CaptureNormalInvertedPair, FinishCapturePair
    case StartStructuredLightingCaptureFull, EndStructuredLightingCaptureFull
    
    case EndCaptureSession  // not yet implemented
    
    case LockWhiteBalance, AutoWhiteBalance // sets white balance modes -- feature not used/relevant, though
}
@objc(CameraInstructionPacket)  // IMPORTANT: this line ensures that both the Mac and iPhone
                                // targets consider this to be the same class during sending/receipt
class CameraInstructionPacket: NSObject, NSCoding {
    // Parameters
    //---IN USE---
    var cameraInstruction: CameraInstruction!
    var resolution: String = "max"   // for setting photo resolution (use constants "AVCaptureSessionPreset...")
    var photoBracketExposureDurations: [Double]?   // values are in seconds
    var photoBracketExposureISOs: [Double]?
    var pointOfFocus: CGPoint?  // point of focus: represents where to focus in field of view
    var lensPosition: Float?    // sets focus
    
    // binary code parameters
    var binaryCodeSystem: BinaryCodeSystem?
    var binaryCodeDirection: Bool?
    var binaryCodeBit: Int?         // bit of binary code being displayed
    var binaryCodeInverted: Bool?   // if binary code is inverted
    
    //---NOT IN USE---
    var torchMode: AVCaptureTorchMode?
    var torchLevel: Float?
    
    //MARK: INITIALIZERS
    
    // public initializer for CameraInstructionPacket
    // NOTE: most values are optional, so they are safe to omit when calling this function unless
    //   you need to use them
    convenience init(cameraInstruction: CameraInstruction, resolution: String = "max", photoBracketExposureDurations: [Double]? = nil, pointOfFocus: CGPoint? = nil, torchMode: AVCaptureTorchMode? = nil, torchLevel: Float? = nil, lensPosition: Float? = nil, binaryCodeBit: Int? = nil, binaryCodeDirection: Bool? = nil, binaryCodeInverted: Bool? = nil, binaryCodeSystem: BinaryCodeSystem? = nil, photoBracketExposureISOs: [Double]? = nil) {
        self.init()
        self.cameraInstruction = cameraInstruction
        self.resolution = resolution
        self.photoBracketExposureDurations = photoBracketExposureDurations
        self.photoBracketExposureISOs = photoBracketExposureISOs
        self.pointOfFocus = pointOfFocus
        self.torchMode = torchMode
        self.torchLevel = torchLevel
        self.lensPosition = lensPosition
        self.binaryCodeBit = binaryCodeBit
        self.binaryCodeDirection = binaryCodeDirection
        self.binaryCodeInverted = binaryCodeInverted
        self.binaryCodeSystem = binaryCodeSystem
        }
    
    // for decoding packet (never called by programmer)
    required convenience init?(coder decoder: NSCoder) {
        self.init()
        self.cameraInstruction = CameraInstruction(rawValue: decoder.decodeInteger(forKey: "cameraInstruction"))
        self.resolution = decoder.decodeObject(forKey: "resolution") as! String
        self.photoBracketExposureDurations = decoder.decodeObject(forKey: "photoBracketExposureDurations") as! [Double]?
        self.photoBracketExposureISOs = decoder.decodeObject(forKey: "photoBracketExposureISOs") as! [Double]?
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
    
    // never called by programmer
    // encodes packet before being sent
    func encode(with coder: NSCoder) {
        coder.encode(self.cameraInstruction.rawValue, forKey: "cameraInstruction")
        coder.encode(self.resolution, forKey: "resolution")
        coder.encode(self.photoBracketExposureDurations, forKey: "photoBracketExposureDurations")
        //coder.encode(self.photoBracketExposureISOs, forKey: "photoBracketExposureISOs")
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
