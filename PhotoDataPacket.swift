//
//  PhotoDataPacket.swift
//  
//
//  Created by Nicholas Mosier on 5/30/17.
//
//

import Foundation

@objc(PhotoDataPacket)
class PhotoDataPacket: NSObject, NSCoding {    
    //MARK: Properties
    var encounteredError: Bool!
    var photoData: Data!
    var bracketedPhotoID: Int?
    var lensPosition: Float?
    
    //MARK: Initialization
    required convenience init?(coder decoder: NSCoder) {
        self.init()
        // decode data using key "photoData"
        self.encounteredError = decoder.decodeObject(forKey: "encounteredError") as! Bool
        self.photoData = decoder.decodeObject(forKey: "photoData") as? Data
        self.bracketedPhotoID = decoder.decodeObject(forKey: "bracketedPhotoID") as! Int?
        self.lensPosition = decoder.decodeObject(forKey: "lensPosition") as! Float?
    }
    
    convenience init(photoData: Data, bracketedPhotoID: Int? = nil, lensPosition: Float? = nil) {
        self.init()
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
        coder.encode(encounteredError, forKey: "encounteredError")
        coder.encode(photoData, forKey: "photoData")
        coder.encode(bracketedPhotoID, forKey: "bracketedPhotoID")
        coder.encode(lensPosition, forKey: "lensPosition")
    }
}
