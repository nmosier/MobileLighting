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

    class CameraController: NSObject, AVCapturePhotoCaptureDelegate, AVCaptureFileOutputRecordingDelegate {
        
    //MARK: constants
    static let preferredExposureTimescale: CMTimeScale = 1000000 // magic number provided by maxExposureDuration property
    
    //MARK: Properties
    var captureSession: AVCaptureSession!
    var captureDevice: AVCaptureDevice!
    var capturePhotoOutput: AVCapturePhotoOutput! // for taking stills
    var movieOutput = AVCaptureMovieFileOutput() // for taking videos
    
    var capturePhotos = [AVCapturePhoto]()
    var lensPositions =  [Float]()
    var sessionPreset: String!
    
    // properties for capturing normal/inverted pairs
    var pixelBuffers_normal = [CVPixelBuffer]()
    var pixelBuffers_inverted = [CVPixelBuffer]()
    var capturingNormalInvertedPair = false
    var capturingInverted: Bool = false
    var currentBinaryCodeBit: Int?
//    var decoder: Decoder?
        
    var isCapturingPhoto: Bool = false
    
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
    var minISO: Float {
        get {
            return self.captureDevice.activeFormat.minISO
        }
    }
    var maxISO: Float {
        get {
            return self.captureDevice.activeFormat.maxISO
        }
    }
    var maxBracketedPhotoCount: Int {
        get {
            return capturePhotoOutput.maxBracketedCapturePhotoCount
        }
    }
    var photoBracketExposureDurations: [Double]?
    var photoBracketExposureISOs: [Double]?
    
    var photoBracketSettings: AVCapturePhotoBracketSettings {
        get {
            if let photoBracketExposureDurations = self.photoBracketExposureDurations, let photoBracketExposureISOs = self.photoBracketExposureISOs {
                var bracketSettings = [AVCaptureManualExposureBracketedStillImageSettings]()
                //for exposure in photoBracketExposureDurations {
                for i in 0..<min(photoBracketExposureDurations.count, photoBracketExposureISOs.count) {
                    var duration: Double = photoBracketExposureDurations[i]
                    var iso: Float = Float(photoBracketExposureISOs[i])
                    // make sure duration within bounds
                    if duration < minExposureDuration.seconds || duration > maxExposureDuration.seconds {
                        print("Exposure duration not within allowed range.\nExposure must be between \(minExposureDuration.seconds) and \(maxExposureDuration.seconds).")
                        duration = max(min(maxExposureDuration.seconds, duration), minExposureDuration.seconds)
                    }
                    if iso < minISO || iso > maxISO {
                        print("Exposure ISO not within allowed range. Exposure must be between \(minISO) and \(maxISO)")
                        iso = max(min(maxISO, iso), minISO)
                    }
                    
                    let exposureTime = CMTime(seconds: duration, preferredTimescale: CameraController.preferredExposureTimescale)
                    bracketSettings.append(AVCaptureManualExposureBracketedStillImageSettings.manualExposureSettings(exposureDuration: exposureTime, iso: iso))
                }
                let pixelFormat = kCVPixelFormatType_32BGRA
                let format: [String : Any] = [kCVPixelBufferPixelFormatTypeKey as String : NSNumber(value: pixelFormat)]  //_32BGRA
                print("Available types: \(capturePhotoOutput.availablePhotoPixelFormatTypes)")
                
                guard capturePhotoOutput.availablePhotoPixelFormatTypes.contains(OSType(NSNumber(value: pixelFormat))) else {
                    fatalError("Does not contain \(pixelFormat)")
                }
                let settings = AVCapturePhotoBracketSettings(rawPixelFormatType: 0, processedFormat: format, bracketedSettings: bracketSettings)
                settings.isAutoStillImageStabilizationEnabled = false
                return settings
            } else {
                // use default exposure settings
                let bracketSettings = [AVCaptureAutoExposureBracketedStillImageSettings.autoExposureSettings(exposureTargetBias: -3.0),
                                       AVCaptureAutoExposureBracketedStillImageSettings.autoExposureSettings(exposureTargetBias: 0.0),
                                       AVCaptureAutoExposureBracketedStillImageSettings.autoExposureSettings(exposureTargetBias: 3.0)]
                let processedFormat: [String : Any] = [AVVideoCodecKey : AVVideoCodecType.jpeg,
                                       AVVideoCompressionPropertiesKey : [AVVideoQualityKey : jpegQuality]]
                return AVCapturePhotoBracketSettings(rawPixelFormatType: 0, processedFormat: processedFormat, bracketedSettings: bracketSettings)
            }
        }
    }
    
    
    //MARK: Initialization
    override init() {
        super.init()
        
        // get proper authorization
        checkCameraAuthorization(checkedCameraAuthorization(_:))
        checkPhotoLibraryAuthorization(checkedCameraAuthorization(_:))
        
        // configure first capture session
        guard let preset = cameraService.resolutionToSessionPreset[defaultResolution] else {
            print("Configuring live camera view with default resolution failed: resolution \(defaultResolution) not recognized.")
            fatalError()
        }
        configureNewSession(sessionPreset: preset)
        
        // capture session should be configured, now start it running
        self.captureSession.startRunning()
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
        
        try! self.captureDevice.lockForConfiguration()
        self.captureDevice.focusMode = .continuousAutoFocus
        self.captureDevice.exposureMode = .continuousAutoExposure
//        self.captureDevice.flashMode = .off
        self.captureDevice.torchMode = .off

        self.captureDevice.whiteBalanceMode = .continuousAutoWhiteBalance
        self.captureDevice.unlockForConfiguration()
        
        self.capturePhotoOutput = AVCapturePhotoOutput()
        self.capturePhotoOutput.isHighResolutionCaptureEnabled = true
        self.capturePhotoOutput.isLivePhotoCaptureEnabled = false
        
        self.captureSession = AVCaptureSession()
        self.captureSession.beginConfiguration()
        self.captureSession.sessionPreset = AVCaptureSession.Preset(rawValue: sessionPreset)
        self.captureSession.addInput(videoInput)
        self.captureSession.addOutput(capturePhotoOutput)
        self.captureSession.addOutput(movieOutput)
        
        // turn off video stabilization
        self.capturePhotoOutput.connection(with: AVMediaType.video)?.preferredVideoStabilizationMode = .off
        self.movieOutput.connection(with: AVMediaType.video)?.preferredVideoStabilizationMode = .off
        self.movieOutput.connection(with: AVMediaType.video)?.videoOrientation = cameraOrientation
        capturePhotoOutput.connection(with: AVMediaType.video)?.videoOrientation = cameraOrientation //.portrait
        
        self.captureSession.commitConfiguration()
        
        print("New session configured.")
    }
    
    func useCaptureSessionPreset(_ sessionPreset: String) throws {
        guard self.captureDevice.supportsSessionPreset(AVCaptureSession.Preset(rawValue: sessionPreset)) else {
            throw NSError()
        }
        
        if self.sessionPreset == nil {
            configureNewSession(sessionPreset: sessionPreset)
        } else if sessionPreset != self.sessionPreset {
            guard self.captureSession.canSetSessionPreset(AVCaptureSession.Preset(rawValue: sessionPreset)) else {
                throw NSError()
            }
            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = AVCaptureSession.Preset(rawValue: sessionPreset)
            self.captureSession.commitConfiguration()
        }
    }
    
    //MARK: Entry-point capture functions
    
    func takePhoto(photoSettings: AVCapturePhotoSettings) {
        guard photoBracketExposureDurations == nil || photoBracketExposureDurations!.count <= maxBracketedPhotoCount else {
            print("Error: cannot capture photo bracket — number of bracketed photos exceeds limit for device.")
            return
        }
        
        print("Capturing photo: \(self.capturePhotoOutput)")
        capturingNormalInvertedPair = false
        capturingInverted = false
        photoSettings.isAutoStillImageStabilizationEnabled = false
        self.capturePhotoOutput.capturePhoto(with: photoSettings, delegate: self)
        self.isCapturingPhoto = true
    }
    
    // main function for capturing normal-inverted pair
    func takeNormalInvertedPair(settings: AVCapturePhotoSettings) {
        guard photoBracketExposureDurations == nil || photoBracketExposureDurations!.count <= maxBracketedPhotoCount else {
            print("Error: cannot capture photo bracket — number of bracketed photos exceeds limit for device.")
            return
        }
        print("CameraController: initiating capture of photo bracket pair.")
        
        capturingNormalInvertedPair = true
        capturingInverted = false
        pixelBuffers_normal.removeAll()
        pixelBuffers_inverted.removeAll()
        
        settings.isAutoStillImageStabilizationEnabled = false
        self.capturePhotoOutput.capturePhoto(with: settings, delegate: self)
        self.isCapturingPhoto = true
    }
    
    // sister function for capturing inverted bracket in normal-inverted pair
    func resumeWithTakingInverted(settings: AVCapturePhotoSettings) {
        guard photoBracketExposureDurations == nil || photoBracketExposureDurations!.count <= maxBracketedPhotoCount else {
            print("Error: cannot capture photo bracket — number of bracketed photos exceeds limit for device.")
            return
        }
        guard capturingNormalInvertedPair else {
            print("CameraController: ERROR - cannot call resumeWithTakingInverted(settings:) without first calling takeNormalInvertedPair(settings:).")
            return
        }
        print("CameraController: capturing inverted bracket of normal-inverted pair.")
        
        //configureNewSession(sessionPreset: AVCaptureSessionPresetHigh)
        //self.captureSession.startRunning()
        
        //capturingNormalInvertedPair = true
        capturingInverted = true
        //currentBinaryCodeBit = 0
        
        settings.isAutoStillImageStabilizationEnabled = false
        self.capturePhotoOutput.capturePhoto(with: settings, delegate: self)
        self.isCapturingPhoto = true
    }
    
    
    //MARK: video capture
    func startVideoRecording(torch torchMode: AVCaptureDevice.TorchMode = .off) {        
        guard !movieOutput.isRecording else {
            print("video: cannot start recording video -- already recording.")
            return
        }
        guard movieOutput.connection(with: AVMediaType.video)?.activeVideoStabilizationMode == .off else {
            print("video: could not turn off video stabilization mode.")
            return
        }
        
        // configure torch mode
        if torchMode == .on {
            do { try self.captureDevice.setTorchModeOn(level: torchModeLevel) }
            catch { print("error in setting torch mode.") }
        }
        
        // start imu data recording
        motionRecorder = MotionRecorder()
        motionRecorder.startRecording()
        
        // start video recording
        let videoURL = URL(fileURLWithPath: tmpVideoDir())
        movieOutput.startRecording(to: videoURL, recordingDelegate: self)
    }
        
    func stopVideoRecording() {
        guard movieOutput.isRecording else {
            print("video: error -- no video is being recorded.")
            return
        }
        movieOutput.stopRecording()
        // delegate method below will be called as soon as video fully processed
        
        // stop imu recording
        motionRecorder.stopRecording()
        
//        self.captureDevice.torchMode = .off
        try? configureCaptureDevice(torchMode: .off)
        
    }
        
        
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        guard !movieOutput.isRecording else {
            // for some reason, this method is called continuously -- need to check to make sure it's actually done recording.
            return
        }
        if let error = error {
            print(error.localizedDescription)
            return
        }
        
        // send video
        guard let videoData = FileManager.default.contents(atPath: outputFileURL.path) else {
            print("video: could not get video data -- perhaps the video file does not exist at path \(outputFileURL.absoluteString)")
            return
        }
        let videoPacket = PhotoDataPacket(photoData: videoData)
        photoSender.sendPacket(videoPacket)
        
        guard let imuData = motionRecorder.generateYML().data(using: .ascii) else {
            print("motion manager: could not get data from IMU data YML string.")
            return
        }
        let imuPacket = PhotoDataPacket(photoData: imuData)
        photoSender.sendPacket(imuPacket)
    }
        
    
    
    //MARK: AVCapturePhotoCaptureDelegate
    /*
    func photoOutput(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?, previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        guard let photoSampleBuffer = photoSampleBuffer else {
            print("photo sample buffer is nil — likely because AVCaptureSessionPreset is incompatible with device camera.")
            print("ERROR: \(error!.localizedDescription)")
            return
        }
        print("CameraController: lens position is \(self.captureDevice.lensPosition)")
        
        if (shouldSaveOriginals) {
            if (!photoSampleBuffer.save()) {
                print("could not save original to Photos.")
            }
        }
        
        if capturingNormalInvertedPair {
            // select correct buffer array (normal/inverted)
            guard var pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(photoSampleBuffer) else {
                print("CameraController: could not get pixel buffer from photo sample buffer.")
                let packet = PhotoDataPacket.error()
                photoSender.sendPacket(packet)
                return
            }
            
            pixelBuffer = pixelBuffer.deepcopy()!
            
            
            if capturingInverted {
                pixelBuffers_inverted.append(pixelBuffer)
            } else {
                pixelBuffers_normal.append(pixelBuffer)
            }
            
            
            
        } else {
            print("flash mode enabled = \(resolvedSettings.isFlashEnabled)")
            
            self.photoSampleBuffers.append(photoSampleBuffer)
            self.lensPositions.append(self.captureDevice.lensPosition)
        }
    }
    */
        
        func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
//            guard let photoSampleBuffer = photoSampleBuffer else {
//                print("photo sample buffer is nil — likely because AVCaptureSessionPreset is incompatible with device camera.")
//                print("ERROR: \(error!.localizedDescription)")
//                return
//            }
//            print("CameraController: lens position is \(self.captureDevice.lensPosition)")
            if let error = error {
                print(error.localizedDescription)
                return
            }
            
            if (shouldSaveOriginals) {
                savePhotoToLibrary(photo)
            }
            
            if capturingNormalInvertedPair {
                // select correct buffer array (normal/inverted)
//                guard var pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(photoSampleBuffer) else {
//                    print("CameraController: could not get pixel buffer from photo sample buffer.")
//                    let packet = PhotoDataPacket.error()
//                    photoSender.sendPacket(packet)
//                    return
//                }
                guard var pixelBuffer = photo.pixelBuffer else {
                    print("CameraController: could not get pixel buffer from photo.")
                    let packet = PhotoDataPacket.error()
                    photoSender.sendPacket(packet)
                    return
                }
                
                pixelBuffer = pixelBuffer.deepcopy()!
                
                
                if capturingInverted {
                    pixelBuffers_inverted.append(pixelBuffer)
                } else {
                    pixelBuffers_normal.append(pixelBuffer)
                }
                
                
                
            } else {
//                print("flash mode enabled = \(resolvedSettings.isFlashEnabled)")
                
//                self.photoSampleBuffers.append(photoSampleBuffer)
                self.capturePhotos.append(photo)
                self.lensPositions.append(self.captureDevice.lensPosition)
            }
            
        }
    
    
    func photoOutput(_ captureOutput: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        guard error == nil else {
            print("ERROR: \(error!.localizedDescription)")
            //self.capturePhotoOutput.capturePhoto(with: photoBracketSettings, delegate: self)
            return
        }
        
        if capturingNormalInvertedPair {
            if capturingInverted {
                // process images
                processCodeImages(normal: pixelBuffers_normal, inverted: pixelBuffers_inverted, for: currentBinaryCodeBit!)
 
                pixelBuffers_normal.removeAll()
                pixelBuffers_inverted.removeAll()
                
                capturingNormalInvertedPair = false
            } else {
                // notify Mac phone is ready to capture inverted image set
                let packet = PhotoDataPacket(photoData: Data(), statusUpdate: .CapturedNormalBinaryCode)
                photoSender.sendPacket(packet)
            }
            capturingInverted = !capturingInverted
        } else {
        
            for index in 0..<capturePhotos.count {
                let photo = self.capturePhotos[index]
                let jpegData: Data
                
                if let imageBuffer: CVPixelBuffer = photo.pixelBuffer { //CMSampleBufferGetImageBuffer(photoSampleBuffer) {
                    let im: CIImage = CIImage(cvPixelBuffer: imageBuffer).oriented(.right)
                    let colorspace = CGColorSpaceCreateDeviceRGB()
                    jpegData = CIContext().jpegRepresentation(of: im, colorSpace: colorspace, options: [kCGImageDestinationLossyCompressionQuality as String : jpegQuality])!
                } else {
//                    jpegData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: photoSampleBuffer, previewPhotoSampleBuffer: nil)!
                    jpegData = photo.fileDataRepresentation()!
                    
                }
                let photoPacket = PhotoDataPacket(photoData: jpegData, bracketedPhotoID: index, lensPosition: lensPositions[index])
                photoSender.sendPacket(photoPacket)
            }
            self.capturePhotos.removeAll()
            self.lensPositions.removeAll()
        }
        self.isCapturingPhoto = false
    }
    
    func savePhotoToLibrary(_ photo: AVCapturePhoto) {
//        let jpegData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: sampleBuffer, previewPhotoSampleBuffer: nil)
        let jpegData = photo.fileDataRepresentation()
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
        if let device = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInDuoCamera,
                                                      for: AVMediaType.video,
                                                      position: .back) {
            return device // use dual camera on supported devices
        } else if let device = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera,
                                                             for: AVMediaType.video,
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
        print("\tlocked: \(device.isFocusModeSupported(AVCaptureDevice.FocusMode.locked))")
        print("\tauto focus: \(device.isFocusModeSupported(AVCaptureDevice.FocusMode.autoFocus))")
        print("\tcontinuous auto focus: \(device.isFocusModeSupported(AVCaptureDevice.FocusMode.continuousAutoFocus))")
        print("\tpoint of interest: \(device.isFocusPointOfInterestSupported)")
        print("-Exposure modes")
        print("\tlocked: \(device.isExposureModeSupported(AVCaptureDevice.ExposureMode.locked))")
        print("\tauto exposure: \(device.isExposureModeSupported(AVCaptureDevice.ExposureMode.autoExpose))")
        print("\tcontinuous auto exposure: \(device.isExposureModeSupported(AVCaptureDevice.ExposureMode.continuousAutoExposure))")
        print("-Has torch mode: \(device.hasTorch)")
    }
    
    //MARK: Device configuration
    func configureCaptureDevice(focusMode: AVCaptureDevice.FocusMode? = nil, focusPointOfInterest: CGPoint? = nil, exposureMode: AVCaptureDevice.ExposureMode? = nil, /* flashMode: AVCaptureDevice.FlashMode? = nil, */
                                torchMode: AVCaptureDevice.TorchMode? = nil, torchLevel: Float? = nil, whiteBalanceMode: AVCaptureDevice.WhiteBalanceMode? = nil) throws {
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
        if let whiteBalanceMode = whiteBalanceMode {
            self.captureDevice.whiteBalanceMode = whiteBalanceMode
        }
//        if let flashMode = flashMode {
//            self.captureDevice.flashMode = flashMode
//        }
        if torchMode == .on, let torchLevel = torchLevel {
            try self.captureDevice.setTorchModeOn(level: torchLevel)
        } else if let torchMode = torchMode {
            self.captureDevice.torchMode = torchMode
        }
        
        self.captureDevice.unlockForConfiguration()
    }
    
    
    func tmpVideoDir() -> String {
        let path = (NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String) + "/trajectory.mov"
//        do { try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil) }
//        catch { fatalError("Couldn't create directory in Documents directory.")}
        return path
    }
}
