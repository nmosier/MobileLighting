//
//  VXMCCtrl.swift
//  SerialTools
//
//  Largely adapted from previous C# code:
//  http://www.cs.middlebury.edu/~schar/research/summer05/jeff/Active%20Lighting/ActiveLighting%203.3.1/VXMCtrl.cpp
//
//  Created by Kyle Meredith on ?
//  Modified by Nicholas Mosier on 7/3/17.

import Foundation
import SwiftSerial
import SerialUtils

public let VXM_MAXDIST = 1000        // actual value unknown

// VXMController: encapsulates functionality for connecting and writing instructions to the VXM robot arm controller
//   over a serial port.
public class VXMController {
    var portName: String
    var VXMport: SerialPort?

    public init(portName: String) {
        self.portName = portName
    }
    
    // see the VXM manual for more details on the commands:
    // http://www.velmex.com/Downloads/User_Manuals/vxm_user_manl.pdf
    
    // Initializes the VXM controller using openPort from serialUtils
    // and finds the negative limit.
    // returns false if there is a problem
    public func startVXM() -> Bool {
        do {
            VXMport = openPort(portName: portName)
            
            // "F" initializes the motor with echo off
            // "V" gets the status to confirm the connection
            // writeString returns the number of bytes written to, which isn't relevant
            // this return value will be ignored throughout (it can be reinstantiated for debugging)
            _ = try VXMport!.writeString("FV")
            
            // readChar() returns the result of the status check
            // status is "x" if it doesn't respond, "R" if it's ready;
            var response: UnicodeScalar = "x"
            response = try VXMport!.readChar()
            if (response != "R") {
                closePort(VXMport!)                 // close the port to free it up
                return false
            }
            
            // clear any commands that might have been stored in the controller
            _ = try VXMport!.writeString("C")
            
            // set the motor type to Vekta PK266
            // see Manual pg 25 for details
            _ = try VXMport!.writeString("setM1M4")
            
            // set the motor speed to 4000 steps/sec
            // "." finishes the speed command, then "R" executes it
            _ = try VXMport!.writeString("S1M4000.R")
            
            // wait until a "^" is received, meaning the command is done executing
            while (response != "^") {
                response = try VXMport!.readChar()
            }
            
            // clear command memory
            _ = try VXMport!.writeString("C")
        } catch {
            print("Error: \(error)")
        }
        return true;
    }
    
    // Moves the motor to the zero position (negative limit) and sets that index to absolute zero
    public func zero() {
        do {
            // move to the negative limit
            _ = try VXMport!.writeString("I1M-0.")       //must end with . after a number
            
            // set this position index to absolute zero
            _ = try VXMport!.writeString("IA1M-0.R")
            
            // wait until a "^" is received, meaning the command is done executing
            var response: UnicodeScalar = " "
            while (response != "^") {
                response = try VXMport!.readChar()
            }
            
            // clear command memory
            _ = try VXMport!.writeString("C")
        } catch {
            print("Error: \(error)")
        }
    }
    
    // Moves the motor to dist millimeters from absolute zero. dist should be
    // positive, since we set absolute zero to be the negative limit.
    // note: 1 millimeter = 200 steps
    public func moveTo(dist: Int) -> Void {
        do {
            // check the status to ready the box for the next program
            _ = try VXMport!.writeString("V")
            
            // write the move command
            _ = try VXMport!.writeString("IA1M\(dist*200).R")
            
            // wait until a '^' is received, meaning the command is done executing
            var response: UnicodeScalar = " "
            while (response != "^") {
                response = try VXMport!.readChar()
            }
            
            // clear command memory
            _ = try VXMport!.writeString("C")
        } catch {
            print("Error: \(error)")
        }
    }
    
    // disconnects current serial port
    public func stop() {
        guard let VXMport = VXMport else {
            print("VXMCtrl: vxm already disconnected.")
            return  // already disconnected
        }
        do {
            // quit the controller (put it back in local mode)
            _ = try VXMport.writeString("Q")
            // close the file handle
            closePort(VXMport);
        } catch {
            print("Error: \(error)")
        }
    }

    // gets command line input
    public func cmdLineInputLoop() {
        var run = true
        
        // This loop will take user input until the exit key ("l" for "leave") is entered
        // "0" triggers the zero() funcion, while all other numbers move the motor to that index
        while run {
            guard let input = readLine() else {
                print("VXMController: failed to get input.")
                break
            }
            if input == "l" {
                run = false
                break
            }
            
            guard let num = Int(input) else {
                print("Enter 0 to zero, int to moveTo(int in mm), l to leave")
                continue
            }
            
            switch num {
            case 0:
                zero()
            case nil:
                print("Enter 0 to zero, int to moveTo(int in mm), l to leave")
            default:
                moveTo(dist: num)
            }
        }
        
        // After the input is finished, close the port
        stop()
    }
}


