//
//  SwitcherCtrl.swift
//  SerialTools
//
//  Created by Kyle Meredith on 6/8/17.
//
//  Modified by Nicholas Mosier on 7/3/17.

import Foundation
import SwiftSerial
import SerialUtils

// Switcher: provides functionality for connecting and writing instructions to the Kramer switcher box
//   over a serial port.
public class Switcher {
    var portName: String
    var port: SerialPort?
    
    public init(portName: String) {
        self.portName = portName
    }
    
    // Initializes the video switcher using openPort from serialUtils
    public func startConnection() -> Void {
        port = openPort(portName: portName)
    }
    
    // closes switcher's serial port
    public func endConnection() -> Void {
        if let port = port {
            closePort(port)
        }
    }
    
    // The following functions use the pattern of hex commands supplied by the Kramer manual:
    // https://k.kramerav.com/downloads/protocols/protocol_2000_rev0_51.pdf
    
    // turns on specified output
    // outNum must be in range [0, 8] (0 addresses all outputs)
    public func turnOn(_ outNum: Int) -> Void {
        guard outNum >= 0 && outNum <= 8 else {
            print("Switcher turnOn() - error: outNum must be between 0 and 8.")
            return
        }
        var cmd: Int = 0x81808101 + (outNum << 16)
        sendCmd(cmd: &cmd, serialPort: port!)
    }
    
    // turns off specified output
    // outNum must be in range [0, 8] (0 addresses all outputs)
    public func turnOff(_ outNum: Int) -> Void {
        guard outNum >= 0 && outNum <= 8 else {
            print("Switcher turnOn() - error: outNum must be between 0 and 8.")
            return
        }
        var cmd: Int = 0x81808001 + (outNum << 16)
        sendCmd(cmd: &cmd, serialPort: port!)
    }
    
    // executes command line input loop (indefinitely)
    public func executeCommand(_ cmd: String) -> Void {
        switch cmd {
        case "0":
            turnOn(0)
        case "1":
            turnOn(1)
        case "2":
            turnOn(2)
        case "3":
            turnOn(3)
        case "4":
            turnOn(4)
        case "5":
            turnOn(5)
        case "6":
            turnOn(6)
        case "7":
            turnOn(7)
        case "8":
            turnOn(8)
            
        case "p":
            turnOff(0)
        case "q":
            turnOff(1)
        case "w":
            turnOff(2)
        case "e":
            turnOff(3)
        case "r":
            turnOff(4)
        case "t":
            turnOff(5)
        case "y":
            turnOff(6)
        case "u":
            turnOff(7)
        case "i":
            turnOff(8)
        default:
            print("instructions")
        }
    }
}
