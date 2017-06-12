// PROGRAM CONTROL
// contains central functions to the program, i.e. setting the camera focus, etc

import Foundation

//MARK: Input utility functions

enum Command: String {      // rawValues are automatically the name of the case, i.e. .help.rawValue == "help" (useful for determining an exhaustive switch statement)
    case help   // 'h'
    case quit   // 'q'
    case take   // 't'
    case connect    // 'c'
    case calibrate  // 'x'
}


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
            captureScene(using: binaryCodeSystem)
        } else if tokens[nextToken] == "ambient" {
            nextToken += 1
            if nextToken >= tokens.count || tokens[nextToken] == "single" {
                // take single
                
            } else if tokens[nextToken] == "full" {
                // full ambient take
            }
        }
    case .connect:
        if nextToken >= tokens.count || tokens[nextToken] == "iphone" {
            // set up PhotoReceiver & CameraServiceBrowser
            initializeIPhoneCommunications()
            // wait for completion
            waitForEstablishedCommunications()
            
        }
    case .calibrate:
        // implement later
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
func captureScene(using system: BinaryCodeSystem) {
    let resolution = "high"
    var currentCodeBit: Int
    let codeBitCount: Int = 10
    //var inverted = false
    var horizontal = false
    var fileNamePrefix: String
    
    // captureNextBinaryCode used as handler for self
    func captureNextBinaryCode() {
        guard cameraServiceBrowser.readyToSendPacket else {
            return
        }
        
        if currentCodeBit >= codeBitCount {
            return
        }
        
        // configure capture of normal photo bracket for current code bit
        displayController.configureDisplaySettings(horizontal: horizontal, inverted: false)
        displayController.windows.first!.displayBinaryCode(forBit: currentCodeBit, system: system)
        let packet = CameraInstructionPacket(cameraInstruction: CameraInstruction.CaptureNormalInvertedPair, resolution: resolution, photoBracketExposures: exposures, binaryCodeBit: currentCodeBit)
        cameraServiceBrowser.sendPacket(packet)
        
        // receive CameraStatusUpdate that normal photo bracket capture finished
        photoReceiver.receiveStatusUpdate(completionHandler: captureInvertedBinaryCode)
        
        
        /*
        displayController.configureDisplaySettings(horizontal: horizontal, inverted: inverted)
        displayController.windows.first!.displayBinaryCode(forBit: currentCodeBit, system: system)
        let packet = CameraInstructionPacket(cameraInstruction: CameraInstruction.CapturePhotoBracket, resolution: "high", photoBracketExposures: exposures)
        cameraServiceBrowser.sendPacket(packet)
        photoReceiver.receivePhotoBracket(name: "\(fileNamePrefix)_b\(currentCodeBit)\(inverted ? "i" : "n")", photoCount: exposures.count, completionHandler: captureNextBinaryCode)
        
        if inverted {
            currentCodeBit += 1
        }
        inverted = !inverted
         */
    }
    
    func captureInvertedBinaryCode(statusUpdate: CameraStatusUpdate) {
        guard cameraServiceBrowser.readyToSendPacket else {
            return
        }
        
        if currentCodeBit >= codeBitCount {
            return
        }
        
        displayController.configureDisplaySettings(horizontal: horizontal, inverted: true)
        let packet = CameraInstructionPacket(cameraInstruction: CameraInstruction.FinishCapturePair, resolution: resolution, photoBracketExposures: exposures, binaryCodeBit: currentCodeBit)
        cameraServiceBrowser.sendPacket(packet)
        
        // now receive bracket
        photoReceiver.receivePhotoBracket(name: "\(fileNamePrefix)_b\(currentCodeBit)", photoCount: 1, completionHandler: captureNextBinaryCode)
        
        currentCodeBit += 1
    }
    
    fileNamePrefix = "\(sceneName)_v"
    horizontal = false
    currentCodeBit = 0  // reset to 0
    //inverted = false
    captureNextBinaryCode()
    
    while currentCodeBit < codeBitCount {}  // wait til finished
    
    /*
    fileNamePrefix = "\(sceneName)_vi"
    displayController.configureDisplaySettings(horizontal: false, inverted: true)
    currentCodeBit = 0
    captureNextBinaryCode()
    
    while currentCodeBit < codeBitCount {}
    */
    
    
    fileNamePrefix = "\(sceneName)_h"
    displayController.configureDisplaySettings(horizontal: true, inverted: false)
    currentCodeBit = 0
    //inverted = false
    horizontal = true
    captureNextBinaryCode()
    
    while currentCodeBit < codeBitCount {}
    
    /*
    fileNamePrefix = "\(sceneName)_hi"
    displayController.configureDisplaySettings(horizontal: true, inverted: true)
    currentCodeBit = 0
    captureNextBinaryCode()
    
    while currentCodeBit < codeBitCount {}
    */
    
    
}
