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
    var captureDevice: AVCaptureDevice!
    var capturePhotoOutput: AVCapturePhotoOutput!
    var photoSampleBuffers = [CMSampleBuffer]()
    var sessionPreset: String!
    
    var minExposureDuration: CMTime {
        get {
            return self.captureDevice.activeFormat.minExposureDuration
        }
    }
    var maxExposureDuration: CMTime {
        get {
            return self.captureDevice.activeFormat.maxExposureDuration
        }
    }
    var photoBracketExposures: [Double]?
    
    var photoBracketSettings: AVCapturePhotoBracketSettings {
        get {
            if let photoBracketExposures = self.photoBracketExposures {
                // use specified exposure settings
                var bracketSettings = [AVCaptureManualExposureBracketedStillImageSettings]()
                for exposure in photoBracketExposures {
                    guard exposure >= minExposureDuration.seconds && exposure <= maxExposureDuration.seconds else {
                        fatalError("Exposures not within allowed range.\nExposure must be between \(minExposureDuration) and \(maxExposureDuration).")
                    }
                    let exposureTime = CMTime(seconds: exposure, preferredTimescale: 1000000)   // magic number provided by maxExposureDuration property
                    bracketSettings.append(AVCaptureManualExposureBracketedStillImageSettings.manualExposureSettings(withExposureDuration: exposureTime, iso: AVCaptureISOCurrent))
                }
                return AVCapturePhotoBracketSettings(rawPixelFormatType: 0, processedFormat: [AVVideoCodecKey : AVVideoCodecJPEG], bracketedSettings: bracketSettings)
            } else {
                // use default exposure settings
                let bracketSettings = [AVCaptureAutoExposureBracketedStillImageSettings.autoExposureSettings(withExposureTargetBias: -3.0)!,
                                       AVCaptureAutoExposureBracketedStillImageSettings.autoExposureSettings(withExposureTargetBias: 0.0)!,
                                       AVCaptureAutoExposureBracketedStillImageSettings.autoExposureSettings(withExposureTargetBias: 3.0)!]
                return AVCapturePhotoBracketSettings(rawPixelFormatType: 0, processedFormat: [AVVideoCodecKey : AVVideoCodecJPEG], bracketedSettings: bracketSettings)
            }
        }
    }
    
    var photoSender: PhotoSender!
    
    //MARK: Initialization
    override init() {
        super.init()
        
        // get proper authorization
        checkCameraAuthorization(checkedCameraAuthorization(_:))
        checkPhotoLibraryAuthorization(checkedCameraAuthorization(_:))
        
        // configure first capture session
        configureNewSession(sessionPreset: AVCaptureSessionPresetPhoto)
        
        // capture session should be configured, now start it running
        self.captureSession.startRunning()
        
        // set up photo sender service browser
        self.photoSender = PhotoSender()
        self.photoSender.startBrowsing()
    }
    
    func configureNewSession(sessionPreset: String) {
        self.sessionPreset = sessionPreset
        
        self.captureDevice = defaultDevice()
        guard let videoInput = try? AVCaptureDeviceInput(device: self.captureDevice) else {
            print("Cannot get video input from camera.")
            return
        }
        
        self.capturePhotoOutput = AVCapturePhotoOutput()
        self.capturePhotoOutput.isHighResolutionCaptureEnabled = true
        self.capturePhotoOutput.isLivePhotoCaptureEnabled = false
        
        self.captureSession = AVCaptureSession()
        self.captureSession.beginConfiguration()
        self.captureSession.sessionPreset = sessionPreset
        self.captureSession.addInput(videoInput)
        self.captureSession.addOutput(capturePhotoOutput)
        self.captureSession.commitConfiguration()
        
        print("New session configured.")
    }
    
    func useCaptureSessionPreset(_ sessionPreset: String) {
        if sessionPreset != self.sessionPreset {
            configureNewSession(sessionPreset: sessionPreset)
        }
    }
    
    func takePhoto(photoSettings: AVCapturePhotoSettings) {
        print("Capturing photo: \(self.capturePhotoOutput)")
        self.capturePhotoOutput.capturePhoto(with: photoSettings, delegate: self)
        print("Started capturing photo.")
    }
    
    //MARK: AVCapturePhotoCaptureDelegate
    func capture(_ captureOutput: AVCapturePhotoOutput, willBeginCaptureForResolvedSettings resolvedSettings: AVCaptureResolvedPhotoSettings) {
    }
    
    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?, previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        //print("Finished processing sample buffer.")
        guard let photoSampleBuffer = photoSampleBuffer else {
            fatalError("photo sample buffer is nil — likely because AVCaptureSessionPreset is incompatible with device camera.")
        }
        self.photoSampleBuffers.append(photoSampleBuffer)
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
