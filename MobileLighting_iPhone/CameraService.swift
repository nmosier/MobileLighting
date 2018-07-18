//
//  CameraService.swift
//  demo_iphone
//
//  Created by Nicholas Mosier on 5/25/17.
//  Copyright © 2017 Nicholas Mosier. All rights reserved.
//

import Foundation
import CocoaAsyncSocket
import AVFoundation
import Yaml

class CameraService: NSObject, NetServiceDelegate, GCDAsyncSocketDelegate {
    //MARK: constants
    let resolutionToSessionPreset: [String : String] = [
        "max"   : AVCaptureSession.Preset.photo.rawValue,
        "high"  : AVCaptureSession.Preset.high.rawValue,
        "medium": AVCaptureSession.Preset.medium.rawValue,
        "low"   : AVCaptureSession.Preset.low.rawValue,
        "352x288":AVCaptureSession.Preset.cif352x288.rawValue,
        "640x480":AVCaptureSession.Preset.vga640x480.rawValue,
        "1280x720":AVCaptureSession.Preset.hd1280x720.rawValue,
        "1920x1080":AVCaptureSession.Preset.hd1920x1080.rawValue,
        "3840x2160":AVCaptureSession.Preset.hd4K3840x2160.rawValue
    ];
    
    let resolutionDim: [String : (Int, Int)] = [
        "max"   : (3264, 2448),
        "high"  : (1920, 1080),
        "3840x2160" : (3840, 2160),
        "1920x1080" : (1920, 1080),
    ];
    
    
    //MARK: Properties
    var service: NetService?
    var services = [NetService]()
    var socket: GCDAsyncSocket!
    
    
    
    // var cameraController = CameraController()
    
    // startBroadcast: sets up CameraService on new socket
    // -causes netServiceDidPublish() to be called if successfully published
    func startBroadcast() {
        socket = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.main)  // delegate set to this CameraService
                                                                                    // so if socket is accepted,
                                                                                    // "socket(didAcceptNewSocket:)"
                                                                                    // will be called (see below)
        do {
            try socket.accept(onInterface: "", port: 0)
            service = NetService(domain: "local.", type: "_cameraService._tcp", name: "CameraService", port: Int32(socket.localPort))      // service is called 'camera' and using 'tcp' protocol
        } catch {
            print("Error while listening to port for connections.")
        }
        if let thisService = service {      // unwraps class property 'service', publishes it to local network
            thisService.delegate = self
            thisService.publish()
        }
    }
    
    // netServiceDidPublish: NetServiceDelegate function
    // -automatically called after startBroadcast() if CameraService successfully published
    func netServiceDidPublish(_ sender: NetService) {
        guard let thisService = service else {      // ensure there is a service to publish
            return
        }
        print("Camera service did publish on port \(thisService.port) in domain \(thisService.domain) under name \(thisService.name)")
    }
    
    // didAcceptNewSocket: GCDAsyncSocketDelegate function
    // -called when a service browser (from the Mac program) connects
    // -starts reading incoming packets immediately
    func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        print("Accepted new socket.")
        socket = newSocket
        socket.delegate = self  // socketDidReadData function will be called
        readPacket()
    }
    
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        // what the heck? this function is called when the socket is CONNECTED, too?
        guard !self.socket.isConnected else {
            return
        }
        self.socket.disconnect()
        print("CameraService disconnected...")
        self.socket = nil
        
        startBroadcast()
    }
    
    
    
    // readPacket: starts to read packet
    //    (is asynchronous, i.e. only initiates the packet-receiving process)
    func readPacket() {
        // read header, which contains the number of bytes that follow
        // using tag 1 for header
        if self.socket.isConnected {
            socket.readData(toLength: UInt(MemoryLayout<UInt16>.size), withTimeout: -1, tag: 1)
        } else {
            print("readPacket: CameraService socket not connected.")
        }
    }
    
    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        // tag = 1: header
        // tag = 2: camera instruction
        print("Read data with tag \(tag).")
        switch tag {
        case 1:
            // is header: verify data is of correct length
            guard data.count == MemoryLayout<UInt16>.size else {
                print("Error in receiving packet: header of unexpected length.")
                return
            }
            let packetDataLength = UInt(data[0])*256 + UInt(data[1])    // convert 2 bytes of header to UInt16
            
            // now read packet body (contains the CameraInstruction)
            socket.readData(toLength: packetDataLength, withTimeout: -1, tag: 2) // tag = 2 to indicate packet body
            break
        case 2:
            // is body: unarchive data as CameraInstructionPacket
            let cameraInstructionPacket = NSKeyedUnarchiver.unarchiveObject(with: data) as? CameraInstructionPacket
            
            guard cameraInstructionPacket != nil else {
                print("Error in receiving packet: failed to unarchive camera instruction.")
                return
            }
            
            // successfully unarchived packet; call packet handler
            handlePacket(cameraInstructionPacket!)
            
            // read next packet
            readPacket()
            break
        default:
            print("Error in receiving packet: unexpected data tag.")
            break
        }
    }
    
    // called when packet has been fully received
    func handlePacket(_ packet: CameraInstructionPacket) {
        print("CameraService: received camera instruction: \(packet.cameraInstruction!) — \(timestampToString(date: Date()))")
        
        if let pointOfFocus = packet.pointOfFocus, cameraController.captureDevice.isFocusPointOfInterestSupported {
            do {
                try cameraController.configureCaptureDevice(focusMode: AVCaptureDevice.FocusMode.autoFocus, focusPointOfInterest: pointOfFocus)
                print("Adjusting point of focus.")
            } catch {
                print("Could not change point of focus.")
            }
        }
        
        do {
            try cameraController.configureCaptureDevice(torchMode: packet.torchMode, torchLevel: packet.torchLevel)    // if not provided, already defaults to nil
        } catch {
            print("Could not change torch mode settings. Using defaults.")
        }
        // handle camera instruction
        // use dispatch queue (async task) -> need to wait for camera adjustment
        
        let handleInstructionQueue = DispatchQueue(label: "com.CameraService.handleInstructionQueue")
        handleInstructionQueue.async {
            while (cameraController.captureDevice.isAdjustingFocus) {}
        
            let resolution: String = packet.resolution

            switch packet.cameraInstruction! {
            case .GetLensPosition:
                let pos: Float = cameraController.captureDevice.lensPosition
                let packet = PhotoDataPacket(photoData: Data(), lensPosition: pos)
                photoSender.sendPacket(packet)
            
            case .LockLensPosition:
                do {
                    try cameraController.captureDevice.lockForConfiguration()
                    cameraController.captureDevice.focusMode = .locked
                } catch {
                    fatalError("Unable to lock capture device for configuration.")
                }
                photoSender.sendPacket(PhotoDataPacket(photoData: Data(), lensPosition: cameraController.captureDevice.lensPosition))
                
            case .SetLensPosition:
                guard var lensPosition = packet.lensPosition else {
                    print("CameraService: error — lens position is nil, cannot be set.")
                    photoSender.sendPacket(PhotoDataPacket.error())
                    return
                }
                
                // completion handler function -> sends packet PhotoDataPacket confirming completion
                func didSetLensPosition(time: CMTime) {
                    photoSender.sendPacket(PhotoDataPacket(photoData: Data(), lensPosition: cameraController.captureDevice.lensPosition))
                }
                do {
                    try cameraController.captureDevice.lockForConfiguration()
                } catch {
                    fatalError("unable to lock for configuration")
                }
                print("TRIED TO SET LENS POSITION: \(lensPosition)")
                
                let finishedFocusing: (CMTime) -> Void = { _ in
                    while cameraController.captureDevice.isAdjustingFocus {}
                    photoSender.sendPacket(PhotoDataPacket(photoData: Data(), lensPosition: cameraController.captureDevice.lensPosition))
                }
                
                if lensPosition < 0.0 || lensPosition > 1.0 {
                    cameraController.captureDevice.focusMode = .autoFocus
                    photoSender.sendPacket(PhotoDataPacket(photoData: Data(), lensPosition: cameraController.captureDevice.lensPosition))
                } else {
                    cameraController.captureDevice.setFocusModeLocked(lensPosition: lensPosition, completionHandler: finishedFocusing)
                }
                
                cameraController.captureDevice.unlockForConfiguration()
                
//                let queueFinishFocus = DispatchQueue(label: "queueFinishFocus")
//                queueFinishFocus.async {
                
                break
            
            case .SetPointOfFocus:
                guard cameraController.captureDevice.isFocusPointOfInterestSupported else {
                    print("CameraService: error - cannot set focus point of interest; function not supported.")
                    return
                }
                do {
                    try cameraController.captureDevice.lockForConfiguration()
                } catch {
                    print("CameraService: error - could not lock capture device for configuration.")
                    return
                }
                guard let pointOfFocus = packet.pointOfFocus else {
                    print("CameraService: error - point of focus missing in packet.")
                    return
                }
                cameraController.captureDevice.focusPointOfInterest = pointOfFocus
                cameraController.captureDevice.focusMode = .autoFocus
                cameraController.captureDevice.unlockForConfiguration()
                
                let queueFinishFocus = DispatchQueue(label: "queueFinishFocus")
                queueFinishFocus.async {
                    while cameraController.captureDevice.isAdjustingFocus {}
                    photoSender.sendPacket(PhotoDataPacket(photoData: Data(), lensPosition: cameraController.captureDevice.lensPosition))
                }
                break
                
            case .LockWhiteBalance:
                guard cameraController.captureDevice.isWhiteBalanceModeSupported(.locked) else {
                    print("CameraService: error - cannot auto focus & lock: one mode is not supported.")
                    return
                }
                
                do {
                    try cameraController.captureDevice.lockForConfiguration()
                } catch {
                    print("CameraService: error - could not lock capture device for configuration.")
                    return
                }
                cameraController.captureDevice.unlockForConfiguration()
                let queueFinishWhiteBalance = DispatchQueue(label: "queueFinishWhiteBalance")
                queueFinishWhiteBalance.async {
                    while cameraController.captureDevice.isAdjustingWhiteBalance {}
                    let packet = PhotoDataPacket(photoData: Data(), statusUpdate: .LockedWhiteBalance)
                    photoSender.sendPacket(packet)
                }
            
            case .AutoWhiteBalance:
                guard cameraController.captureDevice.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) else {
                    print("CameraService: error - cannot auto focus & lock: one mode is not supported.")
                    return
                }
                
                do {
                    try cameraController.captureDevice.lockForConfiguration()
                } catch {
                    print("CameraService: error - could not lock capture device for configuration.")
                    return
                }
                cameraController.captureDevice.whiteBalanceMode = .continuousAutoWhiteBalance
                cameraController.captureDevice.unlockForConfiguration()
                
                let packet = PhotoDataPacket(photoData: Data(), statusUpdate: .SetAutoWhiteBalance)
                photoSender.sendPacket(packet)
                
            case .ReadExposure:
                let exposure = (cameraController.captureDevice.exposureDuration.seconds, cameraController.captureDevice.iso)
                let packet = PhotoDataPacket(photoData: Data(), exposure: exposure)
                photoSender.sendPacket(packet)
                
            case .LockExposure:
                do { try cameraController.captureDevice.lockForConfiguration()
                } catch { print("CameraService: error - could not lock capture device for configuration.")
                    return
                }
                cameraController.captureDevice.exposureMode = .locked
                cameraController.captureDevice.unlockForConfiguration()
            
            case .AutoExposure:
                do { try cameraController.captureDevice.lockForConfiguration()
                } catch { print("CameraService: error - could not lock capture device for configuration.")
                    return
                }
                cameraController.captureDevice.exposureMode = .autoExpose
                cameraController.captureDevice.unlockForConfiguration()
            
            case .SetExposure:
                do { try cameraController.captureDevice.lockForConfiguration() }
                catch { print("CameraService: error - could not lock capture device for configuration."); return }
                cameraController.captureDevice.exposureMode = .locked
                guard var duration = packet.photoBracketExposureDurations?.first, var iso = packet.photoBracketExposureISOs?.first else {
                    print("SetExposure -- exposure durations/isos empty.")
                    return
                }
                if duration == 0 {
                    duration = cameraController.captureDevice.exposureDuration.seconds
                }
                if (iso == 0) {
                    iso = Double(cameraController.captureDevice.iso)
                }
                
                // make sure exposure settings w/i boundaries
                duration = max(cameraController.captureDevice.activeFormat.minExposureDuration.seconds, duration)
                duration = min(cameraController.captureDevice.activeFormat.maxExposureDuration.seconds, duration)
                iso = max(Double(cameraController.captureDevice.activeFormat.minISO), iso)
                iso = min(Double(cameraController.captureDevice.activeFormat.maxISO), iso)
                cameraController.captureDevice.setExposureModeCustom(duration: CMTime(seconds: duration, preferredTimescale: CameraController.preferredExposureTimescale), iso: Float(iso), completionHandler: { print("set exposure with duration \($0)") })
                cameraController.captureDevice.unlockForConfiguration()
                
            case CameraInstruction.CaptureStillImage:
                do {
                    try cameraController.useCaptureSessionPreset(self.resolutionToSessionPreset[resolution]!)
                } catch {
                    print("CameraService: error — capture session preset \(resolution) not supported by device.")
                    photoSender.sendPacket(PhotoDataPacket.error())
                    return
                }
                
                let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecType.jpeg, AVVideoCompressionPropertiesKey : [AVVideoQualityKey : jpegQuality]])
                // configure flash mode (default is OFF)
                if packet.flashMode == .on {
                    settings.flashMode = .on
                } else {
                    // default: turn off flash
                    settings.flashMode = .off
                }
                
                cameraController.takePhoto(photoSettings: settings)    // default settings: JPEG format
                break
                
            case .CapturePhotoBracket:
                guard let exposureDurations = packet.photoBracketExposureDurations, let exposureISOs = packet.photoBracketExposureISOs else {
                    print("ERROR: exposure times not provided for bracketed photo sequence.")
                    break
                }
                cameraController.photoBracketExposureDurations = exposureDurations
                cameraController.photoBracketExposureISOs = exposureISOs
                guard let preset = self.resolutionToSessionPreset[resolution] else {
                    print("Error: resolution \(resolution) is not compatable with this device.")
                    return
                }
                do {
                    try cameraController.useCaptureSessionPreset(preset)
                } catch {
                    print("CameraService: error — capture session preset \(resolution) not supported by device.")
                    for i in 0..<exposureDurations.count {
                        photoSender.sendPacket(PhotoDataPacket.error(onID: i))
                    }
                    return
                }
                
                if packet.flashMode == .on {
                    // take individual images if flash is on
                    do {
                        try cameraController.captureDevice.lockForConfiguration()
                        try cameraController.captureDevice.setTorchModeOn(level: 1.0)
                        cameraController.captureDevice.unlockForConfiguration()
                    } catch {
                        print("capture image bracket: could not turn on torch.")
                    }
                    
                    for (exposureDuration, exposureISO) in zip(exposureDurations, exposureISOs) {
                        
                        let time = CMTime(seconds: exposureDuration, preferredTimescale: CameraController.preferredExposureTimescale)
                        var exposureModeSet = false
                        do { try cameraController.captureDevice.lockForConfiguration() }
                        catch { print("capturebracket: cannot lock camera for configuration."); return }
                        cameraController.captureDevice.setExposureModeCustom(duration: time, iso: Float(exposureISO), completionHandler: { (_) -> Void in exposureModeSet = true })
                        cameraController.captureDevice.unlockForConfiguration()
                        while !exposureModeSet {}
                        
                        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecType.jpeg, AVVideoCompressionPropertiesKey : [AVVideoQualityKey : jpegQuality]])
//                        settings.flashMode = .on
                        cameraController.takePhoto(photoSettings: settings)
                        
                        while cameraController.isCapturingPhoto {}
                        print("done taking photo.")
                        }
                    do {
                        try cameraController.captureDevice.lockForConfiguration()
                        cameraController.captureDevice.torchMode = .off
                        cameraController.captureDevice.unlockForConfiguration()
                    }
                    catch let error { print(error.localizedDescription) }
                    
                } else {
                    // use photo bracket if flash is off
                    let settings = cameraController.photoBracketSettings
                    cameraController.takePhoto(photoSettings: settings)
                }
                break
            
            case .StartVideoCapture:
                print("starting to record video...")
                cameraController.startVideoRecording()
                break
                
            case .EndVideoCapture:
                print("stopping video recording.")
                cameraController.stopVideoRecording()
                break
               
            // main case for capturing normal inverted pair instruction
            case CameraInstruction.CaptureNormalInvertedPair:
                print("CameraService: CAPTURING PAIR. \(timestampToString(date: Date()))")
                guard let exposureDurations = packet.photoBracketExposureDurations else {
                    print("ERROR: exposure times not provided for bracketed photo sequence.")
                    break
                }
                
                sceneMetadata.exposureDurations = exposureDurations
                
                
                guard let exposureISOs = packet.photoBracketExposureISOs else {
                    print("ERROR: exposure ISO values not provided for bracketed photo sequence.")
                    break
                }
                
                cameraController.currentBinaryCodeBit = packet.binaryCodeBit
                cameraController.photoBracketExposureDurations = exposureDurations
                cameraController.photoBracketExposureISOs = exposureISOs
                guard let preset = self.resolutionToSessionPreset[resolution] else {
                    print("Error: resolution \(resolution) is not compatable with this device.")
                    return
                }
                do {
                    try cameraController.useCaptureSessionPreset(preset)
                } catch {
                    print("CameraService: error — capture session preset \(resolution) not supported by device.")
                    for i in 0..<exposureDurations.count {
                        photoSender.sendPacket(PhotoDataPacket.error(onID: i))
                    }
                    return
                }
                
                let settings = cameraController.photoBracketSettings
                settings.flashMode = .off // make sure flash is off
                cameraController.takeNormalInvertedPair(settings: settings)
                break
                
            // "sister" case for capturing inverted bracket of normal-inverted pair
            case CameraInstruction.FinishCapturePair:
                print("CameraService: FINISHING CAPTURE PAIR. \(timestampToString(date: Date()))")
                guard let exposureDurations = packet.photoBracketExposureDurations else {
                    print("ERROR: exposure times not provided for bracketed photo sequence.")
                    break
                }
                guard let exposureISOs = packet.photoBracketExposureISOs else {
                    print("ERROR: exposure ISOs not provided for bracketed photo sequence.")
                    break
                }
                cameraController.photoBracketExposureDurations = exposureDurations
                cameraController.photoBracketExposureISOs = exposureISOs
                guard let preset = self.resolutionToSessionPreset[resolution] else {
                    print("Error: resolution \(resolution) is not compatable with this device.")
                    return
                }
                do {
                    try cameraController.useCaptureSessionPreset(preset)
                } catch {
                    print("CameraService: error — capture session preset \(resolution) not supported by device.")
                    for i in 0..<exposureDurations.count {
                        photoSender.sendPacket(PhotoDataPacket.error(onID: i))
                    }
                    return
                }
                let settings = cameraController.photoBracketSettings
                
                cameraController.resumeWithTakingInverted(settings: settings)
                break
            
            
            case .StartStructuredLightingCaptureFull:
                // for now, specify hard-code in resolution
                print("CURRENT ISO=\(cameraController.captureDevice.iso)")

                // save current focus
                sceneMetadata.focus = cameraController.captureDevice.lensPosition
                guard let binaryCodeSystem = packet.binaryCodeSystem, let dir = packet.binaryCodeDirection else {
                    print("CameraService: error - binary code must be specified for StartStructuredLightingCaptureFull instruction.")
                    photoSender.sendPacket(PhotoDataPacket.error())
                    return
                }
                guard let (width, height) = self.resolutionDim[resolution] else {
                    print("CameraService: error - could not find dimensions of resolution \(resolution)")
                    fatalError()
                }
                decoder = Decoder(width: width, height: height, binaryCodeSystem: binaryCodeSystem)
                binaryCodeDirection = dir
                print("CameraService: TEST - binaryCodeDirection is \(binaryCodeDirection)")

                // make sure torch mode is off
                if cameraController.captureDevice.torchMode != .off {
                    try! cameraController.configureCaptureDevice(torchMode: .off)
                }
            
            case .EndStructuredLightingCaptureFull:
                // need to send off decoded image
                let data = decoder!.getPFMData()
                var packet = PhotoDataPacket(photoData: data)
                photoSender.sendPacket(packet)
                decoder = nil
                binaryCodeDirection = nil
                
                //MARK: SEND METADATA
                let metadata = sceneMetadata.getMetadataYAMLData()
                packet = PhotoDataPacket(photoData: metadata as Data)
                photoSender.sendPacket(packet)
                print("sent metadata packet")
                
            case CameraInstruction.EndCaptureSession:
                cameraController.captureSession.stopRunning()
                print("Capture session ended.")
                
            }
        }
    }
}
