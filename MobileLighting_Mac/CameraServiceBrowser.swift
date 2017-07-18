// CameraServiceBrowser.swift
//
// CameraServiceBrowser class
//
// This class is in charge of communicating with the iPhone's CameraService.
// It is used for finding and connecting to the iPhone's CameraService as well
//    as sending directives to the camera in the form of instruction packets
//    (defined in the .swift file "CameraInstructionPackets.swift").
//
// Public functions:
// -startBrowsing()
// -sendPacket(CameraInstructionPacket)


import Foundation
import CocoaAsyncSocket

class CameraServiceBrowser: NSObject, NetServiceDelegate, NetServiceBrowserDelegate, GCDAsyncSocketDelegate {
    
    //MARK: Properties
    var socket: GCDAsyncSocket!
    var serviceBrowser: NetServiceBrowser!
    var service: NetService!
    var readyToSendPacket = false
    var packetsToSend = [CameraInstructionPacket]()
    
    var readyToSendObserver: ((Void)->Void)?
    
    //MARK: Public functions
    
    // startBrowsing
    // -begins browsing for iPhone's Bonjour service "CameraService"
    public func startBrowsing() {
        serviceBrowser = NetServiceBrowser()
        serviceBrowser.delegate = self
        serviceBrowser.searchForServices(ofType: "_cameraService._tcp", inDomain: "local.")     // will call "netServiceBrowserDidFindService" (NetServiceBrowserDelegate function) when camera service found
    }
    
    // sendPacket
    // -PARAMETERS:
    //   -packet: CameraInstructionPacket to send to device
    public func sendPacket(_ packet: CameraInstructionPacket) {
        // add packet to sending queue
        packetsToSend.append(packet)
        
        if readyToSendPacket {
            writeNextPacket()
        }
    }
    
    // getInstructionPrompt: makes a single prompt at the command line for camera instruction
    public func getInstructionPrompt() {
        print("Camera instruction: ", terminator: "")
        guard let input = readLine() else {
            // failed to get input
            return
        }
        let instructionDict: [String : CameraInstruction] = ["capture still image" : .CaptureStillImage,
                                                             "capture photo bracket" : .CapturePhotoBracket,
                                                             "end capture session" : .EndCaptureSession]
        guard let instruction = instructionDict[input] else {
            // invalid input, do nothing
            return
        }
        
        let instructionPacket = CameraInstructionPacket(cameraInstruction: instruction)
        sendPacket(instructionPacket)
    }
    
    //MARK: Internal functions
    
    // netServiceBrowserDidFindService: NetServiceBrowserDelegate function
    // -sets this CameraServiceBrowser as delegate, intiates attempt to connect to service
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        self.service = service              // add service to this camera service browser
        self.service.delegate = self        // this camera service browser will be responder to service's delegate
        service.resolve(withTimeout: -1)  // if service resolved, delegate method "netServiceDidResolveAddress" will be called (below)
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
            // need to create new socket & connect it to camera service
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
    // -called when CameraInstructionPacket successfully delivered
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
        print("Sending packet #\(packet.hashValue) with timestamp \(timestampToString(date: Date()))")
        
        let packetData = NSKeyedArchiver.archivedData(withRootObject: packet)   // archive packet for sending
        let packetDataLength = UInt16(packetData.count)
        
        var dataToSend = Data(bytes: [UInt8(packetDataLength/256), UInt8(packetDataLength%256)])    // first two bytes (packet head) indicate size of packet body
        dataToSend.append(packetData)   // append packet body
        
        // send data
        socket.write(dataToSend, withTimeout: -1, tag: 0)   // send packet to device
        self.readyToSendPacket = false
    }
    
}
