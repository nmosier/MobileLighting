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

// from Apple's Photo Capture Programmign Guide
// https://developer.apple.com/library/content/documentation/AudioVideo/Conceptual/PhotoCaptureGuide/index.html#//apple_ref/doc/uid/TP40017511
func checkCameraAuthorization(_ completionHandler: @escaping ((_ authorized: Bool) -> Void)) {
    switch AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) {
    case .authorized:
        //The user has previously granted access to the camera.
        completionHandler(true)
        
    case .notDetermined:
        // The user has not yet been presented with the option to grant video access so request access.
        AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler: { success in
            completionHandler(success)
        })
        
    case .denied:
        // The user has previously denied access.
        completionHandler(false)
        
    case .restricted:
        // The user doesn't have the authority to request access e.g. parental restriction.
        completionHandler(false)
    }
}

func checkedCameraAuthorization(_ authorized: Bool) {
    if !authorized {
        print("Camera access denied.")
    }
}

// from Apple's Photo Capture Programmign Guide
// https://developer.apple.com/library/content/documentation/AudioVideo/Conceptual/PhotoCaptureGuide/index.html#//apple_ref/doc/uid/TP40017511
func checkPhotoLibraryAuthorization(_ completionHandler: @escaping ((_ authorized: Bool) -> Void)) {
    switch PHPhotoLibrary.authorizationStatus() {
    case .authorized:
        // The user has previously granted access to the photo library.
        completionHandler(true)
        
    case .notDetermined:
        // The user has not yet been presented with the option to grant photo library access so request access.
        PHPhotoLibrary.requestAuthorization({ status in
            completionHandler((status == .authorized))
        })
        
    case .denied:
        // The user has previously denied access.
        completionHandler(false)
        
    case .restricted:
        // The user doesn't have the authority to request access e.g. parental restriction.
        completionHandler(false)
    }
}

func checkedPhotoLibraryAuthorization(_ authorized: Bool) {
    if !authorized {
        print("Photo library access denied.")
    }
}
