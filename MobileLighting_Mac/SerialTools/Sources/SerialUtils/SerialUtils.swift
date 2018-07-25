// SeriualUtils.swift
//
// Controls opening and closing of serial ports
// Used by SwitcherCtrl and VXMCtrl modules
//
//  Created by Kyle Meredith on ?

import Foundation
import SwiftSerial


// Initializes a SerialPort object from the connection portName with the proper settings
// Use      ls /dev/cu.*     in terminal to find portName
public func openPort(portName: String) -> SerialPort {
    let serialPort: SerialPort = SerialPort(path: portName)
    
    // Use a do catch structure, since the serialPort might fail to open
    do {
        try serialPort.openPort()
        print("Serial port \(portName) opened successfully.")
        serialPort.setSettings(receiveRate: .baud9600,
                               transmitRate: .baud9600,
                               minimumBytesToRead: 1)
    } catch {
        print("Error: \(error)")
    }
    return serialPort
}


// Closes the serial port
public func closePort(_ serialPort: SerialPort) -> Void {
    print("VXMCtrl: closing port")
    
    serialPort.closePort()
    print("Port Closed")
}


// Sends int command cmd to the serial port serialPort
public func sendCmd(cmd: inout Int, serialPort: SerialPort) -> Void {
    do {
        // convert the Int cmd to a data type, which is required by the writeData function
        let data = NSData(bytes: &cmd, length: 4)
        
        // print("Writing <\(data)> to serial port")
        // writeData returns the number of bytes written, which we don't need
        _ = try serialPort.writeData(data as Data)
        let response = try serialPort.readData(ofLength: 4)
        print(response)
        
    } catch {
        print("Error: \(error)")
    }
}
