//
//  PhotoDataPacket.swift
//  
//
//  Created by Nicholas Mosier on 5/30/17.
//
//

import Foundation

@objc(CameraStatusUpdate)
enum CameraStatusUpdate: Int {
    case None
    case LockedWhiteBalance, SetAutoWhiteBalance
    case CapturedNormalBinaryCode
    case CurrentLensPosition
    case CurrentExposure
}

@objc(PhotoDataType)
enum PhotoDataType: Int {
    case None
    case Ambient
    case Calibration
    case StructuredLight_Original
    case StructuredLight_IntensityDiff
    case StructuredLight_Thresholded
    case StructuredLight_Decoded
    case StructuredLight_Filtered
    case StructuredLight_HoleFilled
    case StructuredLight_Refined
    case SceneMetadata  // in this case, photoData is just a .txt file
}

@objc(PhotoDataPacket)
class PhotoDataPacket: NSObject, NSCoding {    
    //MARK: Properties
    var statusUpdate: CameraStatusUpdate!
    var photoType: PhotoDataType!
    var encounteredError: Bool!
    var photoData: Data!
    var bracketedPhotoID: Int?
    var lensPosition: Float?
    var exposure: (Double, Float)?
    
    //MARK: Initialization
    required convenience init?(coder decoder: NSCoder) {
        self.init()
        // decode data using key "photoData"
        self.statusUpdate = CameraStatusUpdate(rawValue: decoder.decodeInteger(forKey: "statusUpdate"))
        self.photoType = PhotoDataType(rawValue: decoder.decodeInteger(forKey: "photoType"))
        self.encounteredError = decoder.decodeObject(forKey: "encounteredError") as! Bool
        self.photoData = decoder.decodeObject(forKey: "photoData") as? Data
        self.bracketedPhotoID = decoder.decodeObject(forKey: "bracketedPhotoID") as! Int?
        self.lensPosition = decoder.decodeObject(forKey: "lensPosition") as! Float?
        let exposure_duration = decoder.decodeObject(forKey: "exposure_duration") as? Double? ?? nil
        let exposure_iso = decoder.decodeObject(forKey: "exposure_iso") as? Float? ?? nil
        if let exposure_duration = exposure_duration, let exposure_iso = exposure_iso {
            self.exposure = (exposure_duration, exposure_iso)
        } else {
            self.exposure = nil
        }
    }
    
    convenience init(photoData: Data, bracketedPhotoID: Int? = nil, lensPosition: Float? = nil, statusUpdate: CameraStatusUpdate = .None, photoType: PhotoDataType = .None, exposure: (Double, Float)? = nil) {
        self.init()
        self.statusUpdate = statusUpdate
        self.photoType = photoType
        self.encounteredError = false
        self.photoData = photoData
        self.bracketedPhotoID = bracketedPhotoID
        self.lensPosition = lensPosition
        self.exposure = exposure
    }
    
    //MARK: predefined packets
    static func error(onID id: Int? = nil) -> PhotoDataPacket {
        let errorPacket = PhotoDataPacket(photoData: Data(), bracketedPhotoID: id)
        errorPacket.encounteredError = true
        return errorPacket
    }
    
    //MARK: encoding/decoding
    func encode(with coder: NSCoder) {
        coder.encode(statusUpdate.rawValue, forKey: "statusUpdate")
        coder.encode(photoType.rawValue, forKey: "photoType")
        coder.encode(encounteredError, forKey: "encounteredError")
        coder.encode(photoData, forKey: "photoData")
        coder.encode(bracketedPhotoID, forKey: "bracketedPhotoID")
        coder.encode(lensPosition, forKey: "lensPosition")
        let exposure_duration = exposure?.0
        let exposure_iso = exposure?.1
        coder.encode(exposure_duration, forKey: "exposure_duration")
        coder.encode(exposure_iso, forKey: "exposure_iso")
    }
}
