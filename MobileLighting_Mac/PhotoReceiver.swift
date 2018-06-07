//
//  PhotoReceiver.swift
//  demo_mac
//
//  Created by Nicholas Mosier on 5/30/17.
//  Copyright © 2017 Nicholas Mosier. All rights reserved.
//

import Foundation
import CocoaAsyncSocket

class PhotoReceiver: NSObject, NetServiceDelegate, GCDAsyncSocketDelegate {
    //MARK: Properties
    var service: NetService?
    var socket: GCDAsyncSocket!
    
    var workingDirectory: String
    
    // for receiving bracketed photo sequences
    var bracketName: String?
    var bracketedPhotosComing: Int?
    
    // handlers for diff. requests of packet types
    var receivingBracket: Bool = false
    var bracketCompletionHandler: (()->Void)?
    var bracketSubpath: String!
    
    var receivingLensPosition: Bool = false
    var lensPositionCompletionHandler: ((Float)->Void)?
    
    var receivingStatusUpdate: Bool = false
    var statusUpdateCompletionHandler: ((CameraStatusUpdate)->Void)?
    
    var receivingCalibrationImage = false
    var calibrationImageID: Int?
    var calibrationImageCompletionHandler: (()->Void)?
    var calibrationSubpath: String!
    
    var receivingDecodedImage = false
    var decodedImageHorizontal = false
    var decodedImageCompletionHandler: ((String)->Void)?
    var decodedImageAbsDir: String!
    
    var receivingSceneMetadata = false
    var sceneMetadataCompletionHandler: (() -> Void)?
    
    var readyToReceive: Bool = false

    init(_ workingDirectory: String) {
        self.workingDirectory = workingDirectory
    }
    
    // startBroadcast: sets up PhotoReceiver service on new socket
    // -causes netServiceDidPublish() to be called if service successfully published
    func startBroadcast() {
        socket = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.main)
        do {
            try socket.accept(onInterface: "", port: 0) // "" -> no restriction
            self.service = NetService(domain: "local.", type: "_photoReceiver._tcp", name: "PhotoReceiver", port: Int32(socket.localPort))
        } catch {
            print("Error while listening to port for connections.")
        }
        if let service = service {
            service.delegate = self
            service.publish()
        }
    }
    
    // netServiceDidPublish: NetServiceDelegate function
    // -automatically called after startBroadcast() if CameraService successfully published
    func netServiceDidPublish(_ sender: NetService) {
        guard let thisService = service else {      // ensure there is a service to publish
            return
        }
        print("PhotoReceiver did publish on port \(thisService.port) in domain \(thisService.domain) under name \(thisService.name)")
    }
    
    // didAcceptNewSocket: GCDAsyncSocketDelegate function
    // -will be called when iPhone's photo sender service browser connects
    // instruction is sent by the CameraServiceBrowser
    func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        print("Accepted new socket.")
        self.socket = newSocket
        self.socket.delegate = self
        self.readyToReceive = true
        
        readPacket()
    }
    
    // readPacket: starts to read packet
    //    (is asynchronous, i.e. only initiates the packet-receiving process)
    func readPacket() {
        // read header, which contains the number of bytes that follow
        // using tag 1 for header
        if self.socket.isConnected {
            self.socket.readData(toLength: UInt(4), withTimeout: -1, tag: 1)
        } else {
            print("readPacket: cannot read packet; socket disconnected.")
        }
        // when header is read, socketDidReadData delegate function (directly below) will be called
    }
    
    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        // tag = 1: header
        // tag = 2: photo data
        print("Read data with tag \(tag)")
        switch tag {
        case 1:
            // is header
            guard data.count == 4 else {
                print("Error in receiving packet: header of unexpected length.")
                return
            }
            var packetDataLength = UInt(0)
            var data_tmp = data
            for _ in 0..<data.count {
                packetDataLength *= 256
                packetDataLength += UInt(data_tmp.last!)
                data_tmp.removeLast()
            }
            print("packetDataLength: \(packetDataLength)")
            
            // now read packet body (contains the CameraInstruction)
            socket.readData(toLength: UInt(packetDataLength), withTimeout: -1, tag: 2) // tag = 2 to indicate packet body
            break
        case 2:
            // is body: unarchive photo data
            let photoDataPacket = NSKeyedUnarchiver.unarchiveObject(with: data) as! PhotoDataPacket
            
            handlePacket(photoDataPacket)
            
           if receivingBracket {
                guard var bracketedPhotosComing = bracketedPhotosComing else {
                    break
                }
            
                //print("PhotoReceiver: handled packet, # bracketed photos coming: \(bracketedPhotosComing)")
            
                bracketedPhotosComing -= 1
                if bracketedPhotosComing == 0 {
                    // finished receiving bracket, clean up properties & call handler
                    self.bracketedPhotosComing = nil
                    self.bracketName = nil
                    self.receivingBracket = false
                    let handler = self.bracketCompletionHandler
                    self.bracketCompletionHandler = nil
                    
                    if let handler = handler {
                        
                        print("4: calling handler - \(timestampToString(date: Date()))")

                        handler()
                    }
                }
                self.bracketedPhotosComing = bracketedPhotosComing
            }
            
            readPacket()
            
            break
        default:
            break
        }
    }
    
    // handlePacket(PhotoDataPacket)
    // -handles provided packet (saves it to file, e.g.)
    func handlePacket(_ packet: PhotoDataPacket) {
        
        if receivingLensPosition {
            if let handler = lensPositionCompletionHandler {
                print("PhotoReceiver: calling lens position completion handler.")
                handler(packet.lensPosition!)
            }
            receivingLensPosition = false
            return
        } else if receivingStatusUpdate {
            if let handler = statusUpdateCompletionHandler {
                print("PhotoReceiver: calling status update completion handler.")
                handler(packet.statusUpdate)
            }
            
            receivingStatusUpdate = false
            return
        }
        
        
        print("3: handling packet - \(timestampToString(date: Date()))")
        
        guard let photoData = packet.photoData else {
            print("PhotoReceiver: failed to unarchive photo data.")
            return
        }
        
        guard !packet.encounteredError else {
            print("PhotoReceiver: encountered error in photo capture/delivery.")
            return
        }
        
        print("PhotoReceiver: focus for photo: \(packet.lensPosition ?? -1.0)")
        
        var filePath: String = workingDirectory
        let fileURL: URL
        var handler: (()->Void)? = nil

        if receivingCalibrationImage {
            //filePath += "/"+calibrationSubpath+"/IMG_\(calibrationImageID ?? 0).JPG"
            filePath = calibrationSubpath + "/IMG\(calibrationImageID ?? 0).JPG"
            fileURL = URL(fileURLWithPath: filePath)
            
            //fileURL = URL(fileURLWithPath: "\(workingDirectory)/\(sceneName)/imgs_calibration/\(subpath)img\(calibrationImageID ?? 0).jpg")
            receivingCalibrationImage = false
            handler = calibrationImageCompletionHandler
        } else if receivingDecodedImage {
            // save as PFM file
            filePath = decodedImageAbsDir+"/result\(decodedImageHorizontal ? 1:0).pfm"
            fileURL = URL(fileURLWithPath: filePath)
            receivingDecodedImage = false
            if decodedImageCompletionHandler != nil {
                // so decoded image file will already have been saved; otherwise calls handler before im written
                handler = {
                    self.decodedImageCompletionHandler!(filePath)
                }
            }
        } else if receivingSceneMetadata {
            print("Receiving scene metadata...")
            let direction: Int = decodedImageHorizontal ? 1 : 0
            filePath = dirStruc.metadataFile(direction)//[filePath, sceneName, metadataSubdir, "metadata-\(decodedImageHorizontal ? "h":"v").yml"].joined(separator: "/")
            fileURL = URL(fileURLWithPath: filePath)
            handler = sceneMetadataCompletionHandler
        } else if let bracketedPhotoID = packet.bracketedPhotoID {
            print("Is bracketed photo with ID \(bracketedPhotoID).")
            
            if bracketName != nil {
                filePath += "/"+bracketSubpath+"/IMG_\(bracketedPhotoID).JPG"
                //fileURL = URL(fileURLWithPath: "\(workingDirectory)/\(sceneName)/imgs_structured/\(bracketName)-\(bracketedPhotoID).jpg")
                fileURL = URL(fileURLWithPath: filePath)
            } else {
                fileURL = URL(fileURLWithPath: "\(workingDirectory)/\(sceneName)/PHOTO_DATA-\(bracketedPhotoID).jpg")
            }
        } else {
            fileURL = URL(fileURLWithPath: "\(workingDirectory)/\(sceneName)/PHOTO-DATA.jpg")
        }
        
        do {
            makeDir(filePath.split(separator: "/").dropLast().joined(separator: "/"))
            try photoData.write(to: fileURL, options: .atomic)
            print("Successfully saved photo data to file \(fileURL).")
        } catch {
            print("Could not write photo data to file \(fileURL)")
        }
        
        // call handler if there is one
        if let handler = handler {
            handler()
        }
    }
    
    // receivePhotoBracket: starts receiving bracketed photo sequence of given photo count with given name
    //     given completion handler called after fully received
    func receivePhotoBracket(name: String, photoCount: Int, completionHandler: @escaping () -> Void, subpath: String) {
        bracketName = name
        bracketedPhotosComing = photoCount
        bracketCompletionHandler = completionHandler
        bracketSubpath = subpath
        receivingBracket = true
        
        print("RECEIVING PHOTO BRACKET WITH PHOTOCOUNT \(photoCount)")
        //readPacket()
    }
    
    func receiveLensPosition(completionHandler: @escaping (Float) -> Void) {
        receivingLensPosition = true
        lensPositionCompletionHandler = completionHandler
    }
    
    func receiveStatusUpdate(completionHandler: @escaping (CameraStatusUpdate)->Void) {
        receivingStatusUpdate = true
        statusUpdateCompletionHandler = completionHandler
    }
    
    func receiveCalibrationImage(ID: Int, completionHandler: @escaping ()->Void, subpath: String) {
        receivingCalibrationImage = true
        calibrationImageID = ID
        calibrationImageCompletionHandler = completionHandler
        calibrationSubpath = subpath
    }
    
    func receiveDecodedImage(horizontal: Bool, completionHandler: @escaping (String)->Void, absDir: String) {
        receivingDecodedImage = true
        decodedImageHorizontal = horizontal
        decodedImageCompletionHandler = completionHandler
        decodedImageAbsDir = absDir
    }
    
    func receiveSceneMetadata(completionHandler: @escaping () -> Void) {
        receivingSceneMetadata = true
        sceneMetadataCompletionHandler = completionHandler
    }
}
