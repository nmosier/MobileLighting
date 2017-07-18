//
//  CameraPermissions
//  demo_iPhone
//
//  Created by Nicholas Mosier on 5/26/17.
//  Copyright © 2017 Nicholas Mosier. All rights reserved.
//
//  CameraPermissions
//    -contains functions necessary to check for / obtain permission for using
//        iPhone camera and photo library
//  OVERVIEW:
//    -checkCameraAuthorization: checks for / obtains permission to use camera
//    -checkedCameraAuthorization: called on completion of checkCameraAuthorization
//    -checkPhotoLibraryAuthorization: checks for / obtains permission to use photo library
//    -checkedPhotoLibraryAuthorization: called on completeion of checkPhotoLibraryAuthorization

import Foundation
import AVFoundation
import Photos

// based on code from Apple's Photo Capture Programming Guide
// https://developer.apple.com/library/content/documentation/AudioVideo/Conceptual/PhotoCaptureGuide/index.html#//apple_ref/doc/uid/TP40017511
func checkCameraAuthorization(_ completionHandler: @escaping ((_ authorized: Bool) -> Void)) {
    switch AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) {
    case .authorized:
        // is authorized
        completionHandler(true)
        
    case .notDetermined:
        // need to ask for access
        AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler: { success in
            completionHandler(success)
        })
        
    case .denied:
        // access already denied
        completionHandler(false)
        
    case .restricted:
        // parental restriction enabled?
        completionHandler(false)
    }
}

func checkedCameraAuthorization(_ authorized: Bool) {
    if !authorized {
        print("Camera access denied.")
    }
}

// based on code from Apple's Photo Capture Programming Guide
// https://developer.apple.com/library/content/documentation/AudioVideo/Conceptual/PhotoCaptureGuide/index.html#//apple_ref/doc/uid/TP40017511
func checkPhotoLibraryAuthorization(_ completionHandler: @escaping ((_ authorized: Bool) -> Void)) {
    switch PHPhotoLibrary.authorizationStatus() {
    case .authorized:
        // can already access photo library
        completionHandler(true)
        
    case .notDetermined:
        // Need to request access
        PHPhotoLibrary.requestAuthorization({ status in
            completionHandler((status == .authorized))
        })
        
    case .denied:
        // access denied
        completionHandler(false)
        
    case .restricted:
        // parental restriction enabled?
        completionHandler(false)
    }
}

func checkedPhotoLibraryAuthorization(_ authorized: Bool) {
    if !authorized {
        print("Photo library access denied.")
    }
}
