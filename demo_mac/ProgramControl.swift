// PROGRAM CONTROL
// contains central functions to the program, i.e. setting the camera focus, etc

import Foundation
import Cocoa
import VXMCtrl
import SwitcherCtrl

//MARK: Input utility functions

enum Command: String {      // rawValues are automatically the name of the case, i.e. .help.rawValue == "help" (useful for determining an exhaustive switch statement)
    case help   // 'h'
    case quit   // 'q'
    case reloadsettings
    
    case take   // 't'
    case connect    // 'c'
    case disconnect, disconnectall
    case calibrate  // 'x'
    case calibrate2pos
    case takefull
    case readfocus, autofocus, setfocus, lockfocus
    case autoexposure, lockexposure
    case lockwhitebalance
    case focuspoint
    case cb     // displays checkerboard
    case black, white
    case diagonal, verticalbars   // displays diagonal stripes (for testing 'diagonal' DLP chip)
    
    // serial control
    case movearm
    case proj
    
    // image processing
    case refine
    case disparity
    //case refineall
    
    // for debugging
    case dispres
    case dispcode
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
        
    case .reloadsettings:
        let usage: String = "usage: reload [attribute_name]" // e.g. exposures
        guard tokens.count == 2 else {
            print(usage)
            break
        }
        
        let initSettings: InitSettings
        do {
            initSettings = try loadInitSettings(filepath: initSettingsPath)
            print("Successfully loaded initial settings.")
        } catch {
            print("Fatal error: could not load init settings")
            break
        }
        
        if tokens[1] == "exposures" {
            print("Reloading exposures...")
            exposures = initSettings.exposures ?? exposures
            print("New exposures: \(exposures)")
        }
        
        
    case .take:
        // optionally followed by "ambient" token
        if nextToken >= tokens.count {
            // capture scene with current configuration (all exposures & binary patterns)
            //captureScene(system: binaryCodeSystem, ordering: BinaryCodeOrdering.NormalThenInverted, projector: <#Int#>)
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
            //waitForEstablishedCommunications()
        case "switcher":
            guard tokens.count == 3 else {
                print("connect switcher: must specify port (e.g. /dev/cu.usbserial\n(hint: ls /dev/cu.*)")
                break
            }
            displayController.switcher = Switcher(portName: tokens[2])
            displayController.switcher!.startConnection()
        case "vxm":
            guard tokens.count == 3 else {
                print("connect vxm: must specify port (e.g. /dev/cu.usbserial\n(hint: ls /dev/cu.*)")
                break
            }
            vxmController = VXMController(portName: tokens[2])
            vxmController.startVXM()
        default:
            print("cannot connect: invalid device name.")
        }
        
    case .disconnect:
        guard tokens.count == 2 else {
            print("usage: disconnect [vxm|switcher]")
            break
        }
        switch tokens[1] {
        case "vxm":
            vxmController.stop()
        case "switcher":
            if let switcher = displayController.switcher {
                switcher.endConnection()
            }
        default:
            print("connect: invalid device \(tokens[1])")
            break
        }
      
    case .disconnectall:
        vxmController.stop()
        displayController.switcher?.endConnection()
        
    case .calibrate:
        let packet = CameraInstructionPacket(cameraInstruction: .CaptureStillImage, resolution: "high")
        if nextToken < tokens.count, let nPhotos = Int(tokens[nextToken]) {
            for i in 0..<nPhotos {
                var receivedCalibrationImage = false
                
                cameraServiceBrowser.sendPacket(packet)
                photoReceiver.receiveCalibrationImage(ID: i, completionHandler: {()->Void in receivedCalibrationImage = true}, subpath: sceneName+"/"+origSubdir+"/"+calibSubdir)
                while !receivedCalibrationImage {}
                
                guard let _ = readLine() else {
                    fatalError("Unexpected error in reading stdin.")
                }
            }
        }
            
        break
            
    case .calibrate2pos:
        let usage = "usage: calibrate2pos [leftPos: Int] [rightPos: Int] [photosCountPerPos: Int] [resolution]?"
        guard tokens.count >= 4 && tokens.count <= 5 else {
            print(usage)
            break
        }
        guard let pos0 = Int(tokens[1]),
            let pos1 = Int(tokens[2]),
            let nPhotos = Int(tokens[3]),
            nPhotos > 0 else {
            print("calibrate2pos: invalid argument(s).")
            break
        }
        let resolution = (tokens.count == 5) ? tokens[4] : "high"   // high is default res
        
        let packet = CameraInstructionPacket(cameraInstruction: .CaptureStillImage, resolution: resolution)
        var receivedCalibrationImage: Bool
        let msgMove = "Hit enter when camera in position."
        let msgBoard = "Hit enter when board repositioned."
        let leftSubdir = sceneName+"/"+origSubdir+"/"+calibSubdir+"/left"
        let rightSubdir = sceneName+"/"+origSubdir+"/"+calibSubdir+"/right"
        
        vxmController.zero()    // reset robot arm
        
        vxmController.moveTo(dist: pos1)
        print(msgMove)
        _ = readLine()
        cameraServiceBrowser.sendPacket(packet)
        receivedCalibrationImage = false
        photoReceiver.receiveCalibrationImage(ID: 0, completionHandler: {()->Void in receivedCalibrationImage=true}, subpath: rightSubdir)
        while !receivedCalibrationImage {}
        
        for i in 0..<nPhotos-1 {
            let dist = (i%2 == 0) ? pos0:pos1
            let subpath = (i%2 == 0) ? leftSubdir:rightSubdir
            vxmController.moveTo(dist: dist)
            print(msgMove)
            _ = readLine() // operator must press enter when in position; also signal to take photo
            cameraServiceBrowser.sendPacket(packet)
            receivedCalibrationImage = false
            photoReceiver.receiveCalibrationImage(ID: i, completionHandler: {()->Void in receivedCalibrationImage=true}, subpath: subpath)
            while !receivedCalibrationImage {}
            
            print(msgBoard)
            _ = readLine()
            cameraServiceBrowser.sendPacket(packet)
            receivedCalibrationImage = false
            photoReceiver.receiveCalibrationImage(ID: i+1, completionHandler: {()->Void in receivedCalibrationImage=true}, subpath: subpath)
            
            while !receivedCalibrationImage {}
        }
        
        vxmController.moveTo(dist: (nPhotos%2 == 0) ? pos1:pos0)
        print(msgMove)
        _ = readLine()
        cameraServiceBrowser.sendPacket(packet)
        receivedCalibrationImage = false
        photoReceiver.receiveCalibrationImage(ID: nPhotos-1, completionHandler: {()->Void in receivedCalibrationImage=true}, subpath: (nPhotos%2 == 0) ? rightSubdir:leftSubdir)
        while !receivedCalibrationImage {}
        
        break
            
        
    case .takefull:
        let usage = "usage: takefull [projector #] [position #] [code system]? [ordering]?"
        // for now, [pos #] simply tells prog where to save files
        let system: BinaryCodeSystem, ordering: BinaryCodeOrdering
        let systems: [String : BinaryCodeSystem] = ["gray" : .GrayCode, "minSW" : .MinStripeWidthCode]
        let orderings: [String : BinaryCodeOrdering] = ["pairs" : .NormalInvertedPairs, "ntheni" : .NormalThenInverted]
        
        guard tokens.count >= 2 else {
            print(usage)
            break
        }
        guard let projector = Int(tokens[1]) else {
            print("takefull: invalid projector number.")
            break
        }
        guard let position = Int(tokens[2]) else {
            print("takefull: invalid position number.")
            break
        }
        
        if tokens.count >= 4, let tmp_system = systems[tokens[nextToken]] {
            system = tmp_system
        } else {
            system = .MinStripeWidthCode
        }
        if tokens.count == 5, let tmp_ordering = orderings[tokens[nextToken]] {
            ordering = tmp_ordering
        } else {
            ordering = .NormalInvertedPairs
        }
        
        //vxmController.moveTo(dist: positions[position])   // move to specified position
        displayController.switcher?.turnOff(0)   // turns off all projs
        print("Hit enter when all projectors off.")
        readLine()
        displayController.switcher?.turnOn(projector)
        print("Hit enter when selected projector ready.")
        readLine()
        
        captureScene(system: system, ordering: ordering, projector: projector, position: position)
        
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
        
        
    case .lockwhitebalance:
        let packet = CameraInstructionPacket(cameraInstruction: .LockWhiteBalance)
        cameraServiceBrowser.sendPacket(packet)
        var receivedUpdate = false
        photoReceiver.receiveStatusUpdate(completionHandler: {(update: CameraStatusUpdate) in receivedUpdate = true})
        while !receivedUpdate {}
        
    case .autoexposure:
        let packet = CameraInstructionPacket(cameraInstruction: .AutoExposure)
        cameraServiceBrowser.sendPacket(packet)
    case .lockexposure:
        let packet = CameraInstructionPacket(cameraInstruction: .LockExposure)
        cameraServiceBrowser.sendPacket(packet)
        
        
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
    case .diagonal:
        let usage = "usage: diagonal [stripe width]"    // width measured horizontally
        guard tokens.count == 2, let stripeWidth = Int(tokens[1]) else {
            print(usage)
            break
        }
        displayController.currentWindow!.displayDiagonal(width: stripeWidth)
        break
    case .verticalbars:
        let usage = "usage: verticalbars [width]"
        guard tokens.count == 2, let stripeWidth = Int(tokens[1]) else {
            print(usage)
            break
        }
        displayController.currentWindow!.displayVertical(width: stripeWidth)
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
            print("usage: proj <proj #>/all [on|off]/[1|0]")
            break
        }
        if let projector = Int(tokens[1]) {
            switch tokens[2] {
            case "on", "1":
                displayController.switcher?.turnOn(projector)
            case "off", "0":
                displayController.switcher?.turnOff(projector)
            default:
                print("Unrecognized argument: \(tokens[2])")
            }
        } else if tokens[1] == "all" {
            switch tokens[2] {
            case "on", "1":
                displayController.switcher?.turnOn(0)
            case "off", "0":
                displayController.switcher?.turnOff(0)
            default:
                print("Unrecognized argument: \(tokens[2])")
            }
        } else {
            print("Not a valid projector number: \(tokens[1])")
        }
        break
        
    case .refine:
        let usage = "usage: refine [imageFilename] [direction (0/1)]"   // direction: 0 = x, 1 = y
        let outdir = scenesDirectory+"/"+sceneName+"/"+computedSubdir+"/"+refinedSubdir
        guard tokens.count == 3 else {
            print(usage)
            break
        }
        let imgpath = scenesDirectory+"/"+sceneName+"/"+computedSubdir+"/"+decodedSubdir+"/"+tokens[1]
        guard let direction = Int32(tokens[2]) else {
            print("refine: error - improper direction (0=x, 1=y).")
            break
        }
        refineDecodedIm(swift2Cstr(outdir), direction, swift2Cstr(imgpath))
        break
    
    case .disparity:
        let usage = "usage: disparity [[projector #] [[left pos #] [right pos #]]?]?"
        guard tokens.count >= 1 && tokens.count <= 4  else {
            print(usage)
            break
        }
        
        if tokens.count == 1 {
            // compute all
            disparityMatch()
        } else {
            // compute for specific projector
            guard let projector = Int(tokens[1]) else {
                print("disparity: invalid projector number \(tokens[1]).")
                break
            }
            if tokens.count == 2 {
                // compute all for projector
                disparityMatch(projector: projector)
            } else {
                // compute specified position pair
                guard let leftpos = Int(tokens[2]), let rightpos = Int(tokens[3]) else {
                    print("disparity: invalid position ID (\(tokens[2]) or \(tokens[3])).")
                    break
                }
                disparityMatch(projector: projector, leftpos: leftpos, rightpos: rightpos)
            }
        }
    
    case .dispres:
        let screen = displayController.currentWindow!
        print("Screen resolution: \(screen.width)x\(screen.height)")
    case .dispcode:
        displayController.currentWindow!.displayBinaryCode(forBit: 0, system: .MinStripeWidthCode)
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

func captureScene(system: BinaryCodeSystem, ordering: BinaryCodeOrdering, projector: Int, position: Int) {
    let resolution = "high"
    var currentCodeBit: Int
    let codeBitCount: Int = 10
    var inverted = false
    var horizontal = false
    var fileNamePrefix: String
    let decodedDir = scenesDirectory+"/"+sceneName+"/"+computedSubdir+"/"+decodedSubdir+"/proj\(projector)/pos\(position)"
    
    var done: Bool = false
    
    // create directory if necessary
    if ordering == .NormalInvertedPairs {   // expect 2 decoded images
        do {
            try FileManager.default.createDirectory(atPath: decodedDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Failed to create directory at \(decodedDir).")
            return
        }
    }
    
    
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
            
                photoReceiver.receivePhotoBracket(name: "\(fileNamePrefix)_b\(currentCodeBit)\(inverted ? "i" : "n")", photoCount: exposures.count, completionHandler: captureNextBinaryCode, subpath: sceneName+"/"+origSubdir+"/"+graycodeSubdir)
            
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
            //photoReceiver.receiveStatusUpdate(completionHandler: {(update: CameraStatusUpdate)->Void in captureNextBinaryCode() })
            photoReceiver.receiveCalibrationImage(ID: currentCodeBit, completionHandler: {photoReceiver.receiveCalibrationImage(ID: currentCodeBit-1, completionHandler: captureNextBinaryCode, subpath: "tmp/thresh/\(horizontal ? "h" : "v")")}, subpath: "tmp/prethresh/\(horizontal ? "h" : "v")")
            
            //photoReceiver.receivePhotoBracket(name: "thresh\(currentCodeBit)_p\(position)", photoCount: 1, completionHandler: {captureNextBinaryCode()}, subpath: "tmp")
            
            currentCodeBit += 1
        }
    }
    
    fileNamePrefix = "\(sceneName)_v"
    horizontal = false
    currentCodeBit = 0  // reset to 0
    //inverted = false
    if ordering == .NormalInvertedPairs {
        let packet = CameraInstructionPacket(cameraInstruction: .StartStructuredLightingCaptureFull, binaryCodeDirection: !horizontal, binaryCodeSystem: system)
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
        //let subpath = sceneName+"/"+computedSubdir+"/"+decodedSubdir
        
        photoReceiver.receiveDecodedImage(horizontal: false, completionHandler: {path in decodedImageHandler(path, horizontal: false, projector: projector, position: position)}, absDir: decodedDir)
        while photoReceiver.receivingDecodedImage || !cameraServiceBrowser.readyToSendPacket {}
        
        
    }
    
    
    fileNamePrefix = "\(sceneName)_h"
    displayController.configureDisplaySettings(horizontal: true, inverted: false)
    currentCodeBit = 0
    //inverted = false
    horizontal = true
    if ordering == .NormalInvertedPairs {
        let packet = CameraInstructionPacket(cameraInstruction: .StartStructuredLightingCaptureFull, binaryCodeDirection: !horizontal, binaryCodeSystem: system)
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
        photoReceiver.receiveDecodedImage(horizontal: true, completionHandler: {path in decodedImageHandler(path, horizontal: true, projector: projector, position: position)}, absDir: decodedDir)
        while photoReceiver.receivingDecodedImage || !cameraServiceBrowser.readyToSendPacket {}
    }
    
}



//MARK: Utility functions


func initializeIPhoneCommunications() {
    cameraServiceBrowser = CameraServiceBrowser()
    photoReceiver = PhotoReceiver(scenesDirectory)
    
    photoReceiver.startBroadcast()
    cameraServiceBrowser.startBrowsing()
}

// waits for both photo receiver & camera service browser communications
// to be established
// NOTE: only call if you're sure it won't seize control of the program, e.g. it should be executed within a DispatchQueue!
func waitForEstablishedCommunications() {
    while !cameraServiceBrowser.readyToSendPacket {}
    while !photoReceiver.readyToReceive {}
}

func configureDisplays() -> Bool {
    displayController = DisplayController()
    guard NSScreen.screens()!.count > 1  else {
        print("Only one screen connected.")
        return false
    }
    
    for screen in NSScreen.screens()! {
        if screen != NSScreen.main()! {
            displayController.createNewWindow(on: screen)
        }
    }
    
    displayController.setCurrentScreen(withID: 0)   // set main secondary screen to be first in array
    return true
}


func swift2Cstr(_ str: String) -> UnsafeMutablePointer<Int8> {
    let nsstr = str as NSString
    return UnsafeMutablePointer<Int8>(mutating: nsstr.utf8String!)
}

func createStaticDirectoryStructure(atPath path: String, structure: [String : Any?]) {
    let fileman = FileManager.default
    
    for subdir in structure.keys {
        if structure[subdir] == nil || structure[subdir]! == nil {
            //print(path+"/"+subdir)
            do {
                try fileman.createDirectory(atPath: path+"/"+subdir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("ProgramControl: could not create static directory structure.")
            }
        } else {
            let substruct = structure[subdir]! as! [String : Any?]
            createStaticDirectoryStructure(atPath: path+"/"+subdir, structure: substruct)
        }
    }
}
