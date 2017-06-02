//
//  CameraController.swift
//  demo_iPhone
//
//  Created by Nicholas Mosier on 5/26/17.
//  Copyright © 2017 Nicholas Mosier. All rights reserved.
//
//  Provides functionality for taking photos & creating image files
import Foundation
import AVFoundation
import Photos

class CameraController: NSObject, AVCapturePhotoCaptureDelegate {
    //MARK: Properties
    var captureSession: AVCaptureSession!
    var capturePhotoOutput: AVCapturePhotoOutput!
    var photoSampleBuffers = [CMSampleBuffer]()
    
    var photoBracketSettings: AVCapturePhotoBracketSettings {
        get {
            let bracketSettings = [AVCaptureAutoExposureBracketedStillImageSettings.autoExposureSettings(withExposureTargetBias: -3.0)!,
                                   AVCaptureAutoExposureBracketedStillImageSettings.autoExposureSettings(withExposureTargetBias: 0.0)!,
                                   AVCaptureAutoExposureBracketedStillImageSettings.autoExposureSettings(withExposureTargetBias: 3.0)!]
            
            return AVCapturePhotoBracketSettings(rawPixelFormatType: 0, processedFormat: [AVVideoCodecKey : AVVideoCodecJPEG], bracketedSettings: bracketSettings)
        }
    }
    
    var photoSender: PhotoSender!
    
    //MARK: Initialization
    override init() {
        super.init()
        
        // get proper authorization
        checkCameraAuthorization(checkedCameraAuthorization(_:))
        checkPhotoLibraryAuthorization(checkedCameraAuthorization(_:))
        
        // configure video input (?)
        let videoCaptureDevice = defaultDevice()
        guard let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else {
            print("Cannot get video input from camera.")
            return
        }
        
        // configure photo output
        let capturePhotoOutput = AVCapturePhotoOutput()
        capturePhotoOutput.isHighResolutionCaptureEnabled = true
        capturePhotoOutput.isLivePhotoCaptureEnabled = capturePhotoOutput.isLivePhotoCaptureSupported
        
        // configure capture session
        self.captureSession = AVCaptureSession()
        self.captureSession.beginConfiguration()
        self.captureSession.sessionPreset = AVCaptureSessionPresetPhoto
        self.captureSession.addInput(videoInput)
        self.captureSession.addOutput(capturePhotoOutput)
        self.captureSession.commitConfiguration()
        
        self.capturePhotoOutput = capturePhotoOutput
        // capture session should be configured, now start it running
        self.captureSession.startRunning()
        
        // set up photo sender service browser
        self.photoSender = PhotoSender()
        self.photoSender.startBrowsing()
    }
    
    func takePhoto(photoSettings: AVCapturePhotoSettings) {
        self.capturePhotoOutput.capturePhoto(with: photoSettings, delegate: self)
    }
    
    //MARK: AVCapturePhotoCaptureDelegate
    func capture(_ captureOutput: AVCapturePhotoOutput, willBeginCaptureForResolvedSettings resolvedSettings: AVCaptureResolvedPhotoSettings) {
    }
    
    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?, previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        print("Finished processing sample buffer.")
        self.photoSampleBuffers.append(photoSampleBuffer!)
    }
    
    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishCaptureForResolvedSettings resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        print("Finished capture.")
        //saveSampleBufferToPhotoLibrary(self.photoSampleBuffer!)
        
        // send to Mac using PhotoSender
        for index in 0..<photoSampleBuffers.count {
            let photoSampleBuffer = photoSampleBuffers[index]
            let jpegData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: photoSampleBuffer, previewPhotoSampleBuffer: nil)
            let photoPacket = PhotoDataPacket(photoData: jpegData!, bracketedPhotoID: index)
            self.photoSender.sendPacket(photoPacket)
        }
        self.photoSampleBuffers.removeAll()
    }
    
    func saveSampleBufferToPhotoLibrary(_ sampleBuffer: CMSampleBuffer) {
        let jpegData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: sampleBuffer, previewPhotoSampleBuffer: nil)
        
        func completionHandler(_ success: Bool, _ error: Error?) {
            if success {
                print("Successfully added photo to library.")
            }
        }
        
        PHPhotoLibrary.shared().performChanges( {
            let creationRequest = PHAssetCreationRequest.forAsset()
            creationRequest.addResource(with: PHAssetResourceType.photo, data: jpegData!, options: nil)
        }, completionHandler: completionHandler(_:_:))
    }
    
    // from Apple's Photo Capture Programmign Guide
    // https://developer.apple.com/library/content/documentation/AudioVideo/Conceptual/PhotoCaptureGuide/index.html#//apple_ref/doc/uid/TP40017511
    func defaultDevice() -> AVCaptureDevice {
        if let device = AVCaptureDevice.defaultDevice(withDeviceType: .builtInDuoCamera,
                                                      mediaType: AVMediaTypeVideo,
                                                      position: .back) {
            return device // use dual camera on supported devices
        } else if let device = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera,
                                                             mediaType: AVMediaTypeVideo,
                                                             position: .back) {
            return device // use default back facing camera otherwise
        } else {
            fatalError("All supported devices are expected to have at least one of the queried capture devices.")
        }
    }
}
