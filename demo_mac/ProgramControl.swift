// PROGRAM CONTROL
// contains central functions to the program, i.e. setting the camera focus, etc

import Foundation




// setLensPosition(_:)
// -Parameters
//      - lensPosition: Float -> what to set the camera's lens position to
// -Return value: Float -> camera's lens position directly after done adjusting focus (may not agree with given pos?)
func setLensPosition(_ lensPosition: Float) -> Float {
    guard lensPosition <= 1.0 && lensPosition >= 0.0 else {
        fatalError("Lens position not in range.")
    }
    
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
    var currentCodeBit: Int
    let codeBitCount: Int = 10
    var fileNamePrefix: String
    
    // captureNextBinaryCode used as handler for self
    func captureNextBinaryCode() {
        guard cameraServiceBrowser.readyToSendPacket else {
            return
        }
        
        if currentCodeBit >= codeBitCount {
            return
        }
        
        displayController.windows.first!.displayBinaryCode(forBit: currentCodeBit, system: system)
        let packet = CameraInstructionPacket(cameraInstruction: CameraInstruction.CapturePhotoBracket, resolution: "high", photoBracketExposures: exposures)
        cameraServiceBrowser.sendPacket(packet)
        photoReceiver.receivePhotoBracket(name: "\(fileNamePrefix)_b\(currentCodeBit)", photoCount: exposures.count, completionHandler: captureNextBinaryCode)
        currentCodeBit += 1
    }
    
    fileNamePrefix = "\(sceneName)_v"
    displayController.configureDisplaySettings(horizontal: false, inverted: false)
    currentCodeBit = 0  // reset to 0
    captureNextBinaryCode()
    
    while currentCodeBit < codeBitCount {}  // wait til finished
    
    fileNamePrefix = "\(sceneName)_vi"
    displayController.configureDisplaySettings(horizontal: false, inverted: true)
    currentCodeBit = 0
    captureNextBinaryCode()
    
    while currentCodeBit < codeBitCount {}
    
    /*
    fileNamePrefix = "\(sceneName)_h"
    displayController.configureDisplaySettings(horizontal: true, inverted: false)
    currentCodeBit = 0
    captureNextBinaryCode()
    
    while currentCodeBit < codeBitCount {}
    
    fileNamePrefix = "\(sceneName)_hi"
    displayController.configureDisplaySettings(horizontal: true, inverted: true)
    currentCodeBit = 0
    captureNextBinaryCode()
    
    while currentCodeBit < codeBitCount {}
    */
    
}
