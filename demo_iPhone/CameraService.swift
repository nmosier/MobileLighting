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

class CameraService: NSObject, NetServiceDelegate, GCDAsyncSocketDelegate {
    //MARK: constants
    let resolutionToSessionPreset: [String : String] = [
        "max"   : AVCaptureSessionPresetPhoto,
        "high"  : AVCaptureSessionPresetHigh,
        "medium": AVCaptureSessionPresetMedium,
        "low"   : AVCaptureSessionPresetLow,
        "352x288":AVCaptureSessionPreset352x288,
        "640x480":AVCaptureSessionPreset640x480,
        "1280x720":AVCaptureSessionPreset1280x720,
        "1920x1080":AVCaptureSessionPreset1920x1080,
        "3840x2160":AVCaptureSessionPreset3840x2160
    ];
    
    
    //MARK: Properties
    var service: NetService?
    var services = [NetService]()
    var socket: GCDAsyncSocket!
    
    
    
    var cameraController = CameraController()
    
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
    
    // readPacket: starts to read packet
    //    (is asynchronous, i.e. only initiates the packet-receiving process)
    func readPacket() {
        // read header, which contains the number of bytes that follow
        // using tag 1 for header
        socket.readData(toLength: UInt(MemoryLayout<UInt16>.size), withTimeout: -1, tag: 1)
        // when header is read, socketDidReadData delegate function (directly below) will be called
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
        
        if let pointOfFocus = packet.pointOfFocus, self.cameraController.captureDevice.isFocusPointOfInterestSupported {
            do {
                try cameraController.configureCaptureDevice(focusMode: AVCaptureFocusMode.autoFocus, focusPointOfInterest: pointOfFocus)
                print("Adjusting point of focus.")
            } catch {
                print("Could not change point of focus.")
            }
        }
        
        do {
            try self.cameraController.configureCaptureDevice(torchMode: packet.torchMode, torchLevel: packet.torchLevel)    // if not provided, already defaults to nil
        } catch {
            print("Could not change torch mode settings. Using defaults.")
        }
        // handle camera instruction
        // use dispatch queue (async task) -> need to wait for camera adjustment
        
        let handleInstructionQueue = DispatchQueue(label: "com.CameraService.handleInstructionQueue")
        handleInstructionQueue.async {
            while (self.cameraController.captureDevice.isAdjustingFocus) {}
            
            switch packet.cameraInstruction! {
            case .GetLensPosition:
                let pos: Float = self.cameraController.captureDevice.lensPosition
                let packet = PhotoDataPacket(photoData: Data(), lensPosition: pos)
                self.cameraController.photoSender.sendPacket(packet)
            
            case .LockLensPosition:
                do {
                    try self.cameraController.captureDevice.lockForConfiguration()
                    self.cameraController.captureDevice.focusMode = .locked
                } catch {
                    fatalError("Unable to lock capture device for configuration.")
                }
                self.cameraController.photoSender.sendPacket(PhotoDataPacket(photoData: Data(), lensPosition: self.cameraController.captureDevice.lensPosition))
                
            case .SetLensPosition:
                guard var lensPosition = packet.lensPosition else {
                    print("CameraService: error — lens position is nil, cannot be set.")
                    self.cameraController.photoSender.sendPacket(PhotoDataPacket.error())
                    return
                }
                
                /*
                if lensPosition < 0.0 || lensPosition > 1.0 {
                    lensPosition = AVCaptureLensPositionCurrent
                } */
                
                // completion handler function -> sends packet PhotoDataPacket confirming completion
                func didSetLensPosition(time: CMTime) {
                    self.cameraController.photoSender.sendPacket(PhotoDataPacket(photoData: Data(), lensPosition: self.cameraController.captureDevice.lensPosition))
                }
                do {
                    try self.cameraController.captureDevice.lockForConfiguration()
                } catch {
                    fatalError("unable to lock for configuration")
                }
                print("TRIED TO SET LENS POSITION: \(lensPosition)")
                if lensPosition < 0.0 || lensPosition > 1.0 {
                    self.cameraController.captureDevice.focusMode = .autoFocus
                } else {
                    self.cameraController.captureDevice.setFocusModeLockedWithLensPosition(lensPosition, completionHandler: nil)
                }
                
                self.cameraController.captureDevice.unlockForConfiguration()
                
                let queueFinishFocus = DispatchQueue(label: "queueFinishFocus")
                queueFinishFocus.async {
                    while self.cameraController.captureDevice.isAdjustingFocus {}
                    self.cameraController.photoSender.sendPacket(PhotoDataPacket(photoData: Data(), lensPosition: self.cameraController.captureDevice.lensPosition))
                }
                
                break
                
            case .LockWhiteBalance:
                guard self.cameraController.captureDevice.isWhiteBalanceModeSupported(.locked) else {
                    print("CameraService: error - cannot auto focus & lock: one mode is not supported.")
                    return
                }
                
                do {
                    try self.cameraController.captureDevice.lockForConfiguration()
                } catch {
                    print("CameraService: error - could not lock capture device for configuration.")
                    return
                }
                
                self.cameraController.captureDevice.whiteBalanceMode = .locked
                self.cameraController.captureDevice.unlockForConfiguration()
                
                let queueFinishWhiteBalance = DispatchQueue(label: "queueFinishWhiteBalance")
                queueFinishWhiteBalance.async {
                    while self.cameraController.captureDevice.isAdjustingWhiteBalance {}
                    let packet = PhotoDataPacket(photoData: Data(), statusUpdate: .LockedWhiteBalance)
                    self.cameraController.photoSender.sendPacket(packet)
                }
                
                break
                
            case CameraInstruction.CaptureStillImage:
                do {
                    try self.cameraController.useCaptureSessionPreset(self.resolutionToSessionPreset[packet.resolution ?? AVCaptureSessionPresetPhoto]!)
                } catch {
                    print("CameraService: error — capture session preset \(String(describing: packet.resolution)) not supported by device.")
                    self.cameraController.photoSender.sendPacket(PhotoDataPacket.error())
                    return
                }
                self.cameraController.takePhoto(photoSettings: AVCapturePhotoSettings())    // default settings: JPEG format
                break
                
            case CameraInstruction.CapturePhotoBracket:
                guard let exposureTimes = packet.photoBracketExposures else {
                    print("ERROR: exposure times not provided for bracketed photo sequence.")
                    break
                }
                self.cameraController.photoBracketExposures = exposureTimes
                guard let preset = self.resolutionToSessionPreset[packet.resolution ?? AVCaptureSessionPresetPhoto] else {
                    print("Error: resolution \(packet.resolution) is not compatable with this device.")
                    return
                }
                do {
                    try self.cameraController.useCaptureSessionPreset(preset)
                } catch {
                    print("CameraService: error — capture session preset \(packet.resolution) not supported by device.")
                    for i in 0..<exposureTimes.count {
                        self.cameraController.photoSender.sendPacket(PhotoDataPacket.error(onID: i))
                    }
                    return
                }
                let settings = self.cameraController.photoBracketSettings
                self.cameraController.takePhoto(photoSettings: settings)
                break
               
            // main case for capturing normal inverted pair instruction
            case CameraInstruction.CaptureNormalInvertedPair:
                print("CameraService: CAPTURING PAIR. \(timestampToString(date: Date()))")
                guard let exposureTimes = packet.photoBracketExposures else {
                    print("ERROR: exposure times not provided for bracketed photo sequence.")
                    break
                }
                self.cameraController.photoBracketExposures = exposureTimes
                guard let preset = self.resolutionToSessionPreset[packet.resolution ?? AVCaptureSessionPresetPhoto] else {
                    print("Error: resolution \(packet.resolution) is not compatable with this device.")
                    return
                }
                do {
                    try self.cameraController.useCaptureSessionPreset(preset)
                } catch {
                    print("CameraService: error — capture session preset \(packet.resolution) not supported by device.")
                    for i in 0..<exposureTimes.count {
                        self.cameraController.photoSender.sendPacket(PhotoDataPacket.error(onID: i))
                    }
                    return
                }
                let settings = self.cameraController.photoBracketSettings
                self.cameraController.takeNormalInvertedPair(settings: settings)
                break
            // "sister" case for capturing inverted bracket of normal-inverted pair
            case CameraInstruction.FinishCapturePair:
                print("CameraService: FINISHING CAPTURE PAIR. \(timestampToString(date: Date()))")
                guard let exposureTimes = packet.photoBracketExposures else {
                    print("ERROR: exposure times not provided for bracketed photo sequence.")
                    break
                }
                self.cameraController.photoBracketExposures = exposureTimes
                guard let preset = self.resolutionToSessionPreset[packet.resolution ?? AVCaptureSessionPresetPhoto] else {
                    print("Error: resolution \(packet.resolution) is not compatable with this device.")
                    return
                }
                do {
                    try self.cameraController.useCaptureSessionPreset(preset)
                } catch {
                    print("CameraService: error — capture session preset \(packet.resolution) not supported by device.")
                    for i in 0..<exposureTimes.count {
                        self.cameraController.photoSender.sendPacket(PhotoDataPacket.error(onID: i))
                    }
                    return
                }
                let settings = self.cameraController.photoBracketSettings
                /*
                self.cameraController.takeNormalInvertedPair(settings: settings)
                break
                */
                
                
                self.cameraController.resumeWithTakingInverted(settings: settings)
                break
                
                
            case CameraInstruction.EndCaptureSession:
                self.cameraController.captureSession.stopRunning()
                print("Capture session ended.")
                
            }
        }
    }
}
