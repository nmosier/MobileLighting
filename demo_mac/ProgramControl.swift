// PROGRAM CONTROL
// contains central functions to the program, i.e. setting the camera focus, etc

import Foundation
import VXMCtrl
import SwitcherCtrl

//MARK: Input utility functions

enum Command: String {      // rawValues are automatically the name of the case, i.e. .help.rawValue == "help" (useful for determining an exhaustive switch statement)
    case help   // 'h'
    case quit   // 'q'
    case take   // 't'
    case connect    // 'c'
    case calibrate  // 'x'
    case takefull
    case readfocus, autofocus, setfocus, lockfocus
    case focuspoint
    case cb     // displays checkerboard
    case black, white
    
    // serial control
    case movearm
    case proj
}


var processingCommand: Bool = false

// nextCommand: prompts for next command at command line, then handles command
// -Return value -> true if program should continue, false if should exit
func nextCommand() -> Bool {
    guard let input = readLine(strippingNewline: true) else {
        // if input empty, simply return & continue execution
        return true
    }
    
    var nextToken = 0
    let tokens = input.components(separatedBy: " ")
    guard let command = Command(rawValue: tokens.first ?? "") else { // "" is invalid token, automatically rejected
        // if input contains no valid commands, return
        return true
    }
    
    processingCommand = true
    
    nextToken += 1
    switch command {
    case .help:
        // to be implemented
        print("help")
    case .quit:
        return false
    case .take:
        // optionally followed by "ambient" token
        if nextToken >= tokens.count {
            // capture scene with current configuration (all exposures & binary patterns)
            captureScene(system: binaryCodeSystem, ordering: BinaryCodeOrdering.NormalThenInverted)
        } else if tokens[nextToken] == "ambient" {
            nextToken += 1
            if nextToken >= tokens.count || tokens[nextToken] == "single" {
                // take single
                
            } else if tokens[nextToken] == "full" {
                // full ambient take
            }
        }
    
    // for connecting devices
    case .connect:
        guard tokens.count >= 2 else {
            print("usage: connect iphone|switcher|vxm")
            break
        }
        switch tokens[1] {
        case "iphone":
            // set up PhotoReceiver & CameraServiceBrowser
            initializeIPhoneCommunications()
            // wait for completion
            waitForEstablishedCommunications()
        case "switcher":
            displayController.configureSwitcher()
        case "vxm":
            vxmController.startVXM()
        default:
            print("cannot connect: invalid device name.")
        }
        
        
    case .calibrate:
        let packet = CameraInstructionPacket(cameraInstruction: .CaptureStillImage, resolution: "high")
        if nextToken < tokens.count, let nPhotos = Int(tokens[nextToken]) {
            for i in 0..<nPhotos {
                var receivedCalibrationImage = false
                
                cameraServiceBrowser.sendPacket(packet)
                photoReceiver.receiveCalibrationImage(ID: i, completionHandler: {()->Void in receivedCalibrationImage = true})
                while !receivedCalibrationImage {}
                
                guard let _ = readLine() else {
                    fatalError("Unexpected error in reading stdin.")
                }
            }
        }
        break
        
    case .takefull:
        // optional arguments: [binary code system] [ordering]
        let system: BinaryCodeSystem, ordering: BinaryCodeOrdering
        let systems: [String : BinaryCodeSystem] = ["gray" : .GrayCode, "minSW" : .MinStripeWidthCode]
        let orderings: [String : BinaryCodeOrdering] = ["pairs" : .NormalInvertedPairs, "ntheni" : .NormalThenInverted]
        if nextToken < tokens.count, let tmp_system = systems[tokens[nextToken]] {
            system = tmp_system
            nextToken += 1
        } else {
            system = .MinStripeWidthCode
        }
        if nextToken < tokens.count, let tmp_ordering = orderings[tokens[nextToken]] {
            ordering = tmp_ordering
            nextToken += 1
        } else {
            ordering = .NormalInvertedPairs
        }
        
        captureScene(system: system, ordering: ordering)
        
        break
    
    case .readfocus:
        let packet = CameraInstructionPacket(cameraInstruction: .GetLensPosition)
        cameraServiceBrowser.sendPacket(packet)
        photoReceiver.receiveLensPosition(completionHandler: { (pos: Float) in
            print("Lens position:\t\(pos)")
            processingCommand = false
        })
        
    
    case .autofocus:
        let readPos = setLensPosition(-1.0)
        processingCommand = false
    
    case .lockfocus:
        let packet = CameraInstructionPacket(cameraInstruction: .LockLensPosition)
        cameraServiceBrowser.sendPacket(packet)
        photoReceiver.receiveLensPosition(completionHandler: { (pos: Float) in
            print("Lens position:\t\(pos)")
            processingCommand = false
        })
        
    case .setfocus:
        guard nextToken < tokens.count else {
            print("\tUSAGE: 'setfocus <lensPosition>', where 0.0 <= lensPosition <= 1.0")
            break
        }
        guard let pos = Float(tokens[nextToken]) else {
            print("ERROR: Could not parse float value for lens position.")
            break
        }
        let readPos = setLensPosition(pos)
        processingCommand = false
    
    case .focuspoint:
        // arguments: x coord then y coord (0.0 <= 1.0, 0.0 <= 1.0)
        guard tokens.count >= 3 else {
            print("focuspoint usage: focuspoint [x_coord] [y_coord]")
            break
        }
        guard let x = Float(tokens[1]), let y = Float(tokens[2]) else {
            
            print("invalid x or y coordinate: must be on interval [0.0, 1.0]")
            break
        }
        let point = CGPoint(x: CGFloat(x), y: CGFloat(y))
        let packet = CameraInstructionPacket(cameraInstruction: .SetPointOfFocus, pointOfFocus: point)
        cameraServiceBrowser.sendPacket(packet)
        photoReceiver.receiveLensPosition(completionHandler: { (_: Float) in
                processingCommand = false
        })
        break
        
    case .cb:
        // display checkerboard pattern
        // optional parameter: side length of square (in pixels)
        let size: Int
        if nextToken < tokens.count, let customSize = Int(tokens[nextToken]) {
            size = customSize
        } else {
            size = 2
        }
        displayController.windows.first!.displayCheckerboard(squareSize: size)
        break
    
    case .black:
        displayController.windows.first!.displayBlack()
        break
    case .white:
        displayController.windows.first!.displayWhite()
        break
        
    case .movearm:
        guard tokens.count >= 2 else {
            print("usage: movearm <int>/MAX/MIN")
            break
        }
        let dist = tokens[1]
        if let dist = Int(dist) {
            vxmController.moveTo(dist: dist)
        } else if dist == "MAX" {
            vxmController.moveTo(dist: VXM_MAXDIST)
        } else if dist == "MIN" {
            vxmController.zero()
        }
        break
    
    case .proj:
        guard tokens.count >= 3 else {
            print("usage: proj <proj #> [on|off]/[1|0]")
            break
        }
        if let projector = Int(tokens[1]) {
            switch tokens[2] {
            case "on", "1":
                displayController.switcher.turnOn(projector)
            case "off", "0":
                displayController.switcher.turnOff(projector)
            default:
                print("Unrecognized argument: \(tokens[2])")
            }
        } else {
            print("Not a valid projector number: \(tokens[1])")
        }
        break
    }
    return true
}





// setLensPosition(_:)
// -Parameters
//      - lensPosition: Float -> what to set the camera's lens position to
// -Return value: Float -> camera's lens position directly after done adjusting focus (may not agree with given pos?)
func setLensPosition(_ lensPosition: Float) -> Float {
    /*
    guard lensPosition <= 1.0 && lensPosition >= 0.0 else {
        fatalError("Lens position not in range.")
    }
 */
    
    let packet = CameraInstructionPacket(cameraInstruction: .SetLensPosition, lensPosition: lensPosition)
    cameraServiceBrowser.sendPacket(packet)
    
    var received = false
    var lensPos: Float = -1.0
    
    func handler(_ lensPosition: Float) {
        lensPos = lensPosition
        received = true
    }
    
    photoReceiver.receiveLensPosition(completionHandler: handler)
    
    while !received {}
    return lensPos
}


// captureFullTake: captures a 'full' take of the scene with structured lighting

func captureScene(system: BinaryCodeSystem, ordering: BinaryCodeOrdering) {
    let resolution = "high"
    var currentCodeBit: Int
    let codeBitCount: Int = 10
    var inverted = false
    var horizontal = false
    var fileNamePrefix: String
    
    var done: Bool = false
    
    // captureNextBinaryCode used as handler for self
    func captureNextBinaryCode() {
        print("CURRENT CODE BIT: \(currentCodeBit)")
        
        
        guard cameraServiceBrowser.readyToSendPacket else {
            print("Program Control: error - camera service browser not ready to send packet.")
            return
        }
 
        if currentCodeBit >= codeBitCount {
            done = true
            return
        } else {
            done = false
        }
        
        switch ordering {
        case .NormalInvertedPairs:
            // configure capture of normal photo bracket for current code bit
            displayController.configureDisplaySettings(horizontal: horizontal, inverted: false)
            displayController.windows.first!.displayBinaryCode(forBit: currentCodeBit, system: system)
            let packet = CameraInstructionPacket(cameraInstruction: CameraInstruction.CaptureNormalInvertedPair, resolution: resolution, photoBracketExposures: exposures, binaryCodeBit: currentCodeBit)
            
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + monitorTimeDelay) {
            
                cameraServiceBrowser.sendPacket(packet)
            
                // receive CameraStatusUpdate that normal photo bracket capture finished
                photoReceiver.receiveStatusUpdate(completionHandler: captureInvertedBinaryCode)
            }
            
            break
        
        case .NormalThenInverted:
            //displayController.configureDisplaySettings(horizontal: horizontal, inverted: inverted)
            displayController.windows.first!.displayBinaryCode(forBit: currentCodeBit, system: system)
            let packet = CameraInstructionPacket(cameraInstruction: CameraInstruction.CapturePhotoBracket, resolution: "high", photoBracketExposures: exposures, binaryCodeBit: currentCodeBit)
            
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + monitorTimeDelay) {
                cameraServiceBrowser.sendPacket(packet)
            
                photoReceiver.receivePhotoBracket(name: "\(fileNamePrefix)_b\(currentCodeBit)\(inverted ? "i" : "n")", photoCount: exposures.count, completionHandler: captureNextBinaryCode)
            
                currentCodeBit += 1
            }
            break
        }
    }
    
    func captureInvertedBinaryCode(statusUpdate: CameraStatusUpdate) {
        
        
        guard cameraServiceBrowser.readyToSendPacket else {
            print("Program Control: error - camera service browser not ready to send packet.")
            return
        }
 
        if currentCodeBit >= codeBitCount {
            done = true
            return
        }
        
        displayController.configureDisplaySettings(horizontal: horizontal, inverted: true)
        displayController.windows.first!.displayBinaryCode(forBit: currentCodeBit, system: system)
        let packet = CameraInstructionPacket(cameraInstruction: CameraInstruction.FinishCapturePair, resolution: resolution, photoBracketExposures: exposures, binaryCodeBit: currentCodeBit)
        
        //let packet = CameraInstructionPacket(cameraInstruction: CameraInstruction.CapturePhotoBracket, resolution: resolution, photoBracketExposures: exposures, binaryCodeBit: currentCodeBit)
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + monitorTimeDelay) {
            
            
            cameraServiceBrowser.sendPacket(packet)
            
            photoReceiver.receivePhotoBracket(name: "\(fileNamePrefix)_b\(currentCodeBit)", photoCount: 1, completionHandler: captureNextBinaryCode)
            
            currentCodeBit += 1
        }
    }
    
    fileNamePrefix = "\(sceneName)_v"
    horizontal = false
    currentCodeBit = 0  // reset to 0
    //inverted = false
    if ordering == .NormalInvertedPairs {
        let packet = CameraInstructionPacket(cameraInstruction: .StartStructuredLightingCaptureFull, binaryCodeSystem: system)
        cameraServiceBrowser.sendPacket(packet)
        while !cameraServiceBrowser.readyToSendPacket {}
    }
    captureNextBinaryCode()
    
    while currentCodeBit < codeBitCount || !done {}  // wait til finished
    
    if ordering == .NormalThenInverted {
        fileNamePrefix = "\(sceneName)_v"
        displayController.configureDisplaySettings(horizontal: false, inverted: true)
        currentCodeBit = 0
        captureNextBinaryCode()
        
        while currentCodeBit < codeBitCount {}
    }
    
    if ordering == .NormalInvertedPairs {
        let packet = CameraInstructionPacket(cameraInstruction: .EndStructuredLightingCaptureFull)
        cameraServiceBrowser.sendPacket(packet)
        photoReceiver.receiveDecodedImage(horizontal: horizontal, completionHandler: {})
        while photoReceiver.receivingDecodedImage || !cameraServiceBrowser.readyToSendPacket {}
    }
    
    
    fileNamePrefix = "\(sceneName)_h"
    displayController.configureDisplaySettings(horizontal: true, inverted: false)
    currentCodeBit = 0
    //inverted = false
    horizontal = true
    if ordering == .NormalInvertedPairs {
        let packet = CameraInstructionPacket(cameraInstruction: .StartStructuredLightingCaptureFull, binaryCodeSystem: system)
        cameraServiceBrowser.sendPacket(packet)
        while !cameraServiceBrowser.readyToSendPacket {}
    }
    captureNextBinaryCode()
    
    while currentCodeBit < codeBitCount || !done {}
    
    if ordering == .NormalThenInverted {
        inverted = true
        fileNamePrefix = "\(sceneName)_h"
        displayController.configureDisplaySettings(horizontal: true, inverted: true)
        currentCodeBit = 0
        captureNextBinaryCode()
        
        while currentCodeBit < codeBitCount {}
    }
    
    if ordering == .NormalInvertedPairs {
        let packet = CameraInstructionPacket(cameraInstruction: .EndStructuredLightingCaptureFull)
        cameraServiceBrowser.sendPacket(packet)
        photoReceiver.receiveDecodedImage(horizontal: horizontal, completionHandler: {})
        while photoReceiver.receivingDecodedImage || !cameraServiceBrowser.readyToSendPacket {}
    }
    
}
