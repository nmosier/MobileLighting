//
//  DataReceiver.swift
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
    
    var readyToReceive: Bool = false
    
    // object-oriented method of communication
    // now uses queue for receivers
    var dataReceivers = List<DataReceiver>()

    init(_ workingDirectory: String) {
        self.workingDirectory = workingDirectory
    }
    
    // startBroadcast: sets up PhotoReceiver service on new socket
    // -causes netServiceDidPublish() to be called if service successfully published
    func startBroadcast() {
        socket = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.main)
        do {
//            try socket.accept(onInterface: "", port: 0) // "" -> no restriction
            try socket.accept(onPort: 0)
            self.service = NetService(domain: "local.", type: "_photoReceiver._tcp", name: "PhotoReceiver", port: Int32(socket.localPort))
        } catch {
            print("Error while listening to port for connections.")
        }
        
        self.service?.delegate = self
        self.service?.publish()
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
    
    
    
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        // what the heck? this function is called when the socket is CONNECTED, too?
        guard !self.socket.isConnected else {
            return
        }
        self.socket.disconnect()
        print("PhotoReceiver disconnected...")
        self.socket = nil
        
        startBroadcast()
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
            
            readPacket()
            
            break
        default:
            break
        }
    }
    
    // handlePacket(PhotoDataPacket)
    // -handles provided packet (saves it to file, e.g.)
    func handlePacket(_ packet: PhotoDataPacket) {
        guard let dataReceiver = self.dataReceivers.popLast() else {
            // not expecting a packet
            print("could not handle packet -- no data receivers in queue.")
            return
        }
        dataReceiver.handle(packet: packet)
        return
    }
}



protocol DataReceiver {
    func handle(packet: PhotoDataPacket) -> Void
}

typealias BlankHandler = () -> Void
typealias Handler<T> = (T) -> Void

class DataWriter {
    func write(data: Data, path: String) {
        let fileURL = URL(fileURLWithPath: path)
        do {
            makeDir(path.split(separator: "/").dropLast().joined(separator: "/"))
            try data.write(to: fileURL, options: .atomic)
            print("Successfully saved photo data to file \(fileURL).")
        } catch {
            print("Could not write photo data to file \(fileURL)")
        }
    }
}

// now actual definitions
class LensPositionReceiver: DataReceiver {
    let completionHandler: Handler<Float>
    func handle(packet: PhotoDataPacket) {
        guard let lensPosition = packet.lensPosition else {
            print("LensPositionReceiver: lens position missing from packet")
            return
        }
        print("Received lens position.")
        self.completionHandler(lensPosition)
    }
    init(_ completionHandler: @escaping Handler<Float>) {
        self.completionHandler = completionHandler
    }
}

extension PhotoReceiver {
    func receiveLensPositionSync() -> Float {
        var done = false
        var lensPos: Float = -1.0
        photoReceiver.dataReceivers.insertFirst(
                LensPositionReceiver { (pos: Float) in
                    print("Lens position:\t\(pos)")
                    done = true
                    lensPos = pos
            }
        )
        while !done {}
        return lensPos
    }
}

class StatusUpdateReceiver: DataReceiver {
    let completionHandler: Handler<CameraStatusUpdate>
    func handle(packet: PhotoDataPacket) {
        print("Received status update.")
        completionHandler(packet.statusUpdate)
    }
    init(_ completionHandler: @escaping Handler<CameraStatusUpdate>) {
        self.completionHandler = completionHandler
    }
}

class CalibrationImageReceiver: DataWriter, DataReceiver {
    let completionHandler: BlankHandler
    let path: String
    func handle(packet: PhotoDataPacket) {
        makeDir(path.split(separator: "/").dropLast().joined(separator: "/"))
        write(data: packet.photoData, path: path)
        print("Received calibration image.")
        completionHandler()
    }
    init(_ completionHandler: @escaping BlankHandler, dir: String, id: Int) {
        self.completionHandler = completionHandler
        self.path = "\(dir)/IMG\(id).JPG"
    }
}

class DecodedImageReceiver: DataWriter, DataReceiver {
    let completionHandler: Handler<String>
    let path: String
    func handle(packet: PhotoDataPacket) {
        write(data: packet.photoData, path: path)
        print("Received decoded image.")
        completionHandler(path)
    }
    init(_ completionHandler: @escaping Handler<String>, path: String, horizontal: Bool) {
        self.completionHandler = completionHandler
        self.path = path
    }
}

class SceneMetadataReceiver: DataWriter, DataReceiver {
    let completionHandler: BlankHandler
    let path: String
    func handle(packet: PhotoDataPacket) {
        write(data: packet.photoData, path: path)
        print("Received scene metadata.")
        completionHandler()
    }
    init(_ completionHandler: @escaping BlankHandler, path: String) {
        self.completionHandler  = completionHandler
        self.path = path
    }
}

class ExposureReceiver: DataReceiver {
    let completionHandler: Handler<(Double, Float)>
    func handle(packet: PhotoDataPacket) {
        print("Received exposure.")
        guard let exposure = packet.exposure else {
            print("Could not receive exposure.")
            return
        }
        completionHandler(exposure)
    }
    init(_ completionHandler: @escaping Handler<(Double, Float)>) {
        self.completionHandler = completionHandler
    }
}

class AmbientImageReceiver: DataWriter, DataReceiver {
    let completionHandler: BlankHandler
    let path: String
    func handle(packet: PhotoDataPacket) {
        print("Received ambient photo.")
        write(data: packet.photoData, path: path)
        completionHandler()
    }
    init(_ completionHandler: @escaping BlankHandler, path: String) {
        self.completionHandler = completionHandler
        self.path = path
    }
}

class AmbientVideoReceiver: DataWriter, DataReceiver {
    let completionHandler: BlankHandler
    let path: String
    func handle(packet: PhotoDataPacket) {
        print("Received video.")
        write(data: packet.photoData, path: path)
        completionHandler()
    }
    init(_ completionHandler: @escaping BlankHandler, path: String) {
        self.completionHandler = completionHandler
        self.path = path
    }
}
