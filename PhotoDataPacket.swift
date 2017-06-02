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
    var photoData: Data!
    var bracketedPhotoID: Int?
    
    required convenience init?(coder decoder: NSCoder) {
        self.init()
        // decode data using key "photoData"
        guard let photoData = decoder.decodeObject(forKey: "photoData") as? Data else {
            print("Failed to decode photo data (using key 'photoData'.")
            return
        }
        self.bracketedPhotoID = decoder.decodeObject(forKey: "bracketedPhotoID") as! Int?
        self.photoData = photoData
    }
    
    convenience init(photoData: Data, bracketedPhotoID: Int? = nil) {
        self.init()
        self.photoData = photoData
        self.bracketedPhotoID = bracketedPhotoID
    }
    
    //MARK: encoding/decoding
    func encode(with coder: NSCoder) {
        coder.encode(photoData, forKey: "photoData")
        coder.encode(bracketedPhotoID, forKey: "bracketedPhotoID")
    }
}
