//
//  PhotoDataPacket.swift
//  
//
//  Created by Nicholas Mosier on 5/30/17.
//
//

import Foundation

enum CameraStatusUpdate: Int {
    case None
    case LockedWhiteBalance
    case CapturedNormalBinaryCode
    case CurrentLensPosition
}

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
    }
    
    convenience init(photoData: Data, bracketedPhotoID: Int? = nil, lensPosition: Float? = nil, statusUpdate: CameraStatusUpdate = .None, photoType: PhotoDataType = .None) {
        self.init()
        self.statusUpdate = statusUpdate
        self.photoType = photoType
        self.encounteredError = false
        self.photoData = photoData
        self.bracketedPhotoID = bracketedPhotoID
        self.lensPosition = lensPosition
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
    }
}
