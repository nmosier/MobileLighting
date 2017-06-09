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
    //MARK: constants
    static let preferredExposureTimescale: CMTimeScale = 1000000 // magic number provided by maxExposureDuration property
    
    //MARK: Properties
    var captureSession: AVCaptureSession!
    var captureDevice: AVCaptureDevice!
    var capturePhotoOutput: AVCapturePhotoOutput!
    var photoSampleBuffers = [CMSampleBuffer]()
    var lensPositions =  [Float]()
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
    var maxBracketedPhotoCount: Int {
        get {
            return capturePhotoOutput.maxBracketedCapturePhotoCount
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
                    
                    let exposureTime = CMTime(seconds: exposure, preferredTimescale: CameraController.preferredExposureTimescale)
                    bracketSettings.append(AVCaptureManualExposureBracketedStillImageSettings.manualExposureSettings(withExposureDuration: exposureTime, iso: AVCaptureISOCurrent))
                }
                let format: [String : Any] = [kCVPixelBufferPixelFormatTypeKey as String : NSNumber(value: kCVPixelFormatType_32BGRA)]
                guard capturePhotoOutput.availablePhotoPixelFormatTypes.contains(NSNumber(value: kCVPixelFormatType_32BGRA)) else {
                    fatalError("Does not contain kCVPixelFormatType_32BGRA")
                }
                return AVCapturePhotoBracketSettings(rawPixelFormatType: 0, processedFormat: format, bracketedSettings: bracketSettings)
            } else {
                // use default exposure settings
                let bracketSettings = [AVCaptureAutoExposureBracketedStillImageSettings.autoExposureSettings(withExposureTargetBias: -3.0)!,
                                       AVCaptureAutoExposureBracketedStillImageSettings.autoExposureSettings(withExposureTargetBias: 0.0)!,
                                       AVCaptureAutoExposureBracketedStillImageSettings.autoExposureSettings(withExposureTargetBias: 3.0)!]
                let processedFormat: [String : Any] = [AVVideoCodecKey : AVVideoCodecJPEG,
                                       AVVideoCompressionPropertiesKey : [AVVideoQualityKey : NSNumber(value: 0.0)]]
                return AVCapturePhotoBracketSettings(rawPixelFormatType: 0, processedFormat: processedFormat, bracketedSettings: bracketSettings)
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
        if captureSession != nil && captureSession.isRunning {  // make sure capture session isn't running
            captureSession.stopRunning()
        }
        
        self.sessionPreset = sessionPreset
        
        self.captureDevice = defaultDevice()
        guard let videoInput = try? AVCaptureDeviceInput(device: self.captureDevice) else {
            print("Cannot get video input from camera.")
            return
        }
        
        printDeviceCapabilities(of: self.captureDevice)
        
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
    
    func useCaptureSessionPreset(_ sessionPreset: String) throws {
        guard self.captureDevice.supportsAVCaptureSessionPreset(sessionPreset) else {
            throw NSError()
        }
        
        if self.sessionPreset == nil {
            configureNewSession(sessionPreset: sessionPreset)
        } else if sessionPreset != self.sessionPreset {
            guard self.captureSession.canSetSessionPreset(sessionPreset) else {
                throw NSError()
            }
            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = sessionPreset
            self.captureSession.commitConfiguration()
        }
    }
    
    func takePhoto(photoSettings: AVCapturePhotoSettings) {
        guard photoBracketExposures == nil || photoBracketExposures!.count <= maxBracketedPhotoCount else {
            print("Error: cannot capture photo bracket — number of bracketed photos exceeds limit for device.")
            return
        }
        print("Capturing photo: \(self.capturePhotoOutput)")
        self.capturePhotoOutput.capturePhoto(with: photoSettings, delegate: self)
    }
    
    //MARK: AVCapturePhotoCaptureDelegate
    func capture(_ captureOutput: AVCapturePhotoOutput, willBeginCaptureForResolvedSettings resolvedSettings: AVCaptureResolvedPhotoSettings) {
    }
    
    func capture(_ captureOutput: AVCapturePhotoOutput, willCapturePhotoForResolvedSettings resolvedSettings: AVCaptureResolvedPhotoSettings) {
    }
    
    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?, previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        //print("Finished processing sample buffer.")
        print("CameraController: FOCUS pos: \(self.captureDevice.lensPosition)")
        guard let photoSampleBuffer = photoSampleBuffer else {
            print("photo sample buffer is nil — likely because AVCaptureSessionPreset is incompatible with device camera.")
            self.photoSender.sendPacket(PhotoDataPacket.error())  // send error
            return
        }
        self.photoSampleBuffers.append(photoSampleBuffer)
        self.lensPositions.append(self.captureDevice.lensPosition)
    }
    
    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishCaptureForResolvedSettings resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        print("Finished capture.")
        
        // send to Mac using PhotoSender
        
        for index in 0..<photoSampleBuffers.count {
            let photoSampleBuffer = photoSampleBuffers[index]
            
            let desc = CMSampleBufferGetFormatDescription(photoSampleBuffer)
            print("DESC: \(desc!)")
            
            guard let imageBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(photoSampleBuffer) else { fatalError("COULD NOT GET PIXEL BUFFER") }
            let im: CIImage = CIImage(cvPixelBuffer: imageBuffer)
            let colorspace = CGColorSpaceCreateDeviceRGB()
            
            
            //guard let jpegData = CIContext().jpegRepresentation(of: im, colorSpace: colorspace) else { fatalError("COULD NOT GET JPEG DATA") }
            guard let jpegData = CIContext().jpegRepresentation(of: im, colorSpace: colorspace, options: [kCGImageDestinationLossyCompressionQuality as String : 0.9]) else { fatalError("COULDNT GET JPEG DATA") }
 
            /*
            guard let tiffData = CIContext().tiffRepresentation(of: im, format: kCIFormatBGRA8, colorSpace: colorspace) else { fatalError("Could not get TIFF data") } */
            
            //let jpegData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: photoSampleBuffer, previewPhotoSampleBuffer: nil)
            
            let photoPacket = PhotoDataPacket(photoData: jpegData, bracketedPhotoID: index, lensPosition: lensPositions[index])
            self.photoSender.sendPacket(photoPacket)
        }
        self.photoSampleBuffers.removeAll()
        self.lensPositions.removeAll()
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
    
    // based on code from Apple's Photo Capture Programming Guide
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
            fatalError("No capture device found.")
        }
    }
    
    //MARK: Utility functions
    
    func printDeviceCapabilities(of device: AVCaptureDevice) {
        print("CAPABILITIES OF CAPTURE DEVICE \(device.description):")
        print("Focus point of interest supported: \(device.isFocusPointOfInterestSupported)")
        print("-Focus modes:")
        print("\tlocked: \(device.isFocusModeSupported(AVCaptureFocusMode.locked))")
        print("\tauto focus: \(device.isFocusModeSupported(AVCaptureFocusMode.autoFocus))")
        print("\tcontinuous auto focus: \(device.isFocusModeSupported(AVCaptureFocusMode.continuousAutoFocus))")
        print("\tpoint of interest: \(device.isFocusPointOfInterestSupported)")
        print("-Exposure modes")
        print("\tlocked: \(device.isExposureModeSupported(AVCaptureExposureMode.locked))")
        print("\tauto exposure: \(device.isExposureModeSupported(AVCaptureExposureMode.autoExpose))")
        print("\tcontinuous auto exposure: \(device.isExposureModeSupported(AVCaptureExposureMode.continuousAutoExposure))")
        print("-Has torch mode: \(device.hasTorch)")
    }
    
    //MARK: Device configuration
    func configureCaptureDevice(focusMode: AVCaptureFocusMode? = nil, focusPointOfInterest: CGPoint? = nil, exposureMode: AVCaptureExposureMode? = nil, flashMode: AVCaptureFlashMode? = nil,
                                torchMode: AVCaptureTorchMode? = nil, torchLevel: Float? = nil) throws {
        try self.captureDevice.lockForConfiguration()
        
        if let focusPointOfInterest = focusPointOfInterest {
            self.captureDevice.focusPointOfInterest = focusPointOfInterest
        }
        if let focusMode = focusMode {
            self.captureDevice.focusMode = focusMode
        }
        if let exposureMode = exposureMode {
            self.captureDevice.exposureMode = exposureMode
        }
        if let flashMode = flashMode {
            self.captureDevice.flashMode = flashMode    // deprecated, but including anyway (should be changed using AVCapturePhotoSettings.flashMode)
        }
        if torchMode == .on, let torchLevel = torchLevel {
            try self.captureDevice.setTorchModeOnWithLevel(torchLevel)
        } else if let torchMode = torchMode {
            self.captureDevice.torchMode = torchMode
        }
        
        self.captureDevice.unlockForConfiguration()
    }
}
