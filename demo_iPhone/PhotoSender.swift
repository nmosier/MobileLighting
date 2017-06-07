//
//  PhotoSender.swift
//  demo_iPhone
//
//  Created by Nicholas Mosier on 5/30/17.
//  Copyright © 2017 Nicholas Mosier. All rights reserved.
//

import Foundation
import CocoaAsyncSocket

class PhotoSender: NSObject, NetServiceDelegate, NetServiceBrowserDelegate, GCDAsyncSocketDelegate {
    //MARK: Properties
    var socket: GCDAsyncSocket!
    var serviceBrowser: NetServiceBrowser!
    var service: NetService!
    var readyToSendPacket = false
    var packetsToSend = [PhotoDataPacket]()
    
    //MARK: Public functions
    
    // startBrowsing
    // -begins browsing for Mac's Bonjour service "PhotoReceiver"
    public func startBrowsing() {
        serviceBrowser = NetServiceBrowser()
        serviceBrowser.delegate = self
        serviceBrowser.searchForServices(ofType: "_photoReceiver._tcp", inDomain: "local.")     // will call "netServiceBrowserDidFindService" (NetServiceBrowserDelegate function) when photo receiver found
    }
    
    // sendPacket
    // -PARAMETERS:
    //   -packet: PhotoDataPacket to send to Mac
    public func sendPacket(_ packet: PhotoDataPacket) {
        // add packet to sending queue
        packetsToSend.append(packet)
        
        if readyToSendPacket {
            writeNextPacket()
        }
    }
    
    //MARK: Internal functions
    
    // netServiceBrowserDidFindService: NetServiceBrowserDelegate function
    // -sets this CameraServiceBrowser as delegate, intiates attempt to connect to service
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        self.service = service              // add service to this camera service browser
        self.service.delegate = self        // this camera service browser will be responder to service's delegate
        service.resolve(withTimeout: 30.0)  // if service resolved, delegate method "netServiceDidResolveAddress" will be called (below)
    }
    
    // netServiceDidResolveAddress: NetServiceDelegate function
    // -if service address is successfully resolved, connects with service
    func netServiceDidResolveAddress(_ sender: NetService) {
        let isConnected = connectWithService(service: sender)
        self.readyToSendPacket = isConnected
        
        if isConnected {
            print("Connected with service on port \(sender.port) in domain \(sender.domain) under name \(sender.name)")
        } else {
            print("Failed to connect to service.")
        }
    }
    
    // netServiceDidNotResolveAddress: NetServiceDelegate function
    // -removes service as delegate on failure to resolve address
    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        service.delegate = nil  // service failed to resolve
        service = nil
    }
    
    // connectWithService
    // -attempts to connect with service
    // (precondition: service must have resolved address(es))
    // -returns "true" on success, "false" on failure
    func  connectWithService(service: NetService) -> Bool {
        let addresses = service.addresses!
        
        if (self.socket == nil || !self.socket.isConnected) {
            // need to create new socket & connect it to Mac's photo receiver service
            socket = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.main)
            
            // iterate through addresses until successful connection established
            for address in addresses {
                do {
                    try socket.connect(toAddress: address)
                    return true                         // successfully connected, return true
                } catch {
                    print("Failed to connect to address \(address).")
                }
            }
            return false    // unabled to connect to any addresses of service
        } else {
            // if socket already created, return its current connection status
            return socket.isConnected
        }
    }
    
    // socketDidWriteData: GCDAsyncSocketDelegate function
    // -called when PhotoDataPacket successfully delivered
    func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        guard tag == 0 else {
            return
        }
        self.readyToSendPacket = socket.isConnected // ready to send next packet if socket still connected
        
        // remove sent packet from queue
        self.packetsToSend.removeFirst()
        writeNextPacket()
    }

    // writeNextPacket: writes next packet in queue
    func writeNextPacket() {
        guard !packetsToSend.isEmpty else {
            return
        }
        let packet = packetsToSend.first!
        print("Sending packet #\(packet.hashValue)")
        
        let packetData = NSKeyedArchiver.archivedData(withRootObject: packet)   // archive packet for sending
        
        var packetDataLength = UInt32(packetData.count)
        print("packetDataLength: \(packetDataLength)")
        var dataToSend = Data()
        for _ in 0..<4 {
            dataToSend.append(UInt8(packetDataLength % UInt32(256)))
            packetDataLength /= 256
        }
        
        //var dataToSend = Data(bytes: [UInt8(packetDataLength/256), UInt8(packetDataLength%256)])    // first two bytes (packet head) indicate size of packet body
        dataToSend.append(packetData)   // append packet body
        
        // send data
        socket.write(dataToSend, withTimeout: -1, tag: 0)   // send packet to Mac
        self.readyToSendPacket = false
    }

    
}
