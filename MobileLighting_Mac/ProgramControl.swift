// PROGRAM CONTROL
// contains central functions to the program, i.e. setting the camera focus, etc

import Foundation
import Cocoa
import VXMCtrl
import SwitcherCtrl
import Yaml


//MARK: COMMAND-LINE INPUT

enum Command: String {      // rawValues are automatically the name of the case, i.e. .help.rawValue == "help" (useful for ensuring the command-handling switch statement is exhaustive)
    case help
    case quit
    case reloadsettings
    
    case takefull
    case readfocus, autofocus, setfocus, lockfocus
    case autoexposure, lockexposure
    case lockwhitebalance
    case focuspoint
    case cb     // displays checkerboard
    case black, white
    case diagonal, verticalbars   // displays diagonal stripes (for testing 'diagonal' DLP chip)
    
    // communications & serial control
    case connect
    case disconnect, disconnectall
    case proj
    
    // robot control
    case movearm
    case addpos
    
    // image processing
    case refine
    case disparity
    case rectify
    
    // camera calibration
    case calibrate  // 'x'
    case calibrate2pos
    case getintrinsics
    
    // for debugging
    case dispres
    case dispcode
    
}

let commandUsage: [Command : String] = [
    .help: "help",
    .quit: "quit",
    .reloadsettings: "reloadsettings [attribute_name]",
    .connect: "connect [iphone|switcher|vxm] [port string]?",
    .disconnect: "disconnect [vxm|switcher]",
    .calibrate: "calibrate [# of photos]",
    .calibrate2pos: "calibrate2pos [leftPos: Int] [rightPos: Int] [photosCountPerPos: Int] [resolution]?",
    .takefull: "takefull [projector #] [position #] [code system]?",
    .setfocus: "setfocus [lensPosition] (0.0 <= lensPosition <= 1.0)",
    .focuspoint: "focuspoint [x_coord] [y_coord]",
    .cb: "cb [squareSize]?",
    .diagonal: "diagonal [stripe width]",
    .verticalbars: "verticalbars [width]",
    .movearm: "movearm [pose_string | pose_number]",
    .proj: "proj [projector_#|all] [on|off]|[1|0]",
    .refine: "refine [imageFilename] [direction (0/1)]",
    .disparity: "disparity [[projector #] [[left pos #] [right pos #]]?]?",
    .rectify: "rectify [proj#] [pos1] [pos2]",
    .addpos: "addpos [pos_string] [pos_id]?",
]


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
        // rereads init settings file and reloads specified attribute
        // currently only supports changing exposures at runtime
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
            exposureDurations = initSettings.exposureDurations ?? exposureDurations
            print("New exposures: \(exposureDurations)")
        }
    
    // connect: use to connect external devices
    case .connect:
        guard tokens.count >= 2 else {
            print("usage: connect [iphone|switcher|vxm] [port string]?")
            break
        }
        
        switch tokens[1] {
        case "iphone":
            initializeIPhoneCommunications()
            
        case "switcher":
            guard tokens.count == 3 else {
                print("usage: connect switcher: must specify port (e.g. /dev/cu.usbserial\n(hint: ls /dev/cu.*)")
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
            _ = vxmController.startVXM()
            
        default:
            print("cannot connect: invalid device name.")
        }
        
    // disconnect: use to disconnect vxm or switcher (generally not necessary)
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
      
    // disconnects both switcher and vxm box
    case .disconnectall:
        vxmController.stop()
        displayController.switcher?.endConnection()
        
    
    // takes specified number of calibration images; saves them to (scene)/orig/calibration/other
    case .calibrate:
        guard tokens.count == 2 else {
            print("usage: calibrate [# of photos]")
            break
        }
        let packet = CameraInstructionPacket(cameraInstruction: .CaptureStillImage, resolution: defaultResolution)
        let position = currentPos
        //let subpath = dirStruc.calibrationPos(position)//sceneName+"/"+origSubdir+"/"+calibSubdir+"/chessboard"
        // makeDir(scenesDirectory+subpath)
        let subpath = dirStruc.intrinsicsPhotos
        if nextToken < tokens.count, let nPhotos = Int(tokens[nextToken]) {
            for i in 0..<nPhotos {
                var receivedCalibrationImage = false
                
                cameraServiceBrowser.sendPacket(packet)
//                photoReceiver.receiveCalibrationImage(ID: i, completionHandler: {()->Void in receivedCalibrationImage = true}, subpath: subpath)
                let completionHandler = { receivedCalibrationImage = true }
                photoReceiver.dataReceiver = CalibrationImageReceiver(completionHandler, dir: subpath, id: i)
                
                while !receivedCalibrationImage {}
                
                guard let _ = readLine() else {
                    fatalError("Unexpected error in reading stdin.")
                }
            }
        }
        break
       
    // captures calibration images from two viewpoints
    // viewpoints specified as integers corresponding to the position along the linear
    //    robot arm's axis
    // NOTE: requires user to hit 'enter' to indicate robot arm has finished moving to
    //     proper location
    case .calibrate2pos:
        let usage = "usage: calibrate2pos [leftPos: Int] [rightPos: Int] [photosCountPerPos: Int] [resolution]?"
        guard tokens.count >= 4 && tokens.count <= 5 else {
            print(usage)
            break
        }
        guard let left = Int(tokens[1]),
            let right = Int(tokens[2]),
            let nPhotos = Int(tokens[3]),
            nPhotos > 0 else {
            print("calibrate2pos: invalid argument(s).")
            break
        }
        let resolution = (tokens.count == 5) ? tokens[4] : defaultResolution   // high is default res
        captureStereoCalibration(left: left, right: right, nPhotos: nPhotos, resolution: resolution)
        break
    
    // captures scene using structured lighting from specified projector and position number
    // - code system to use is an optional parameter: can either be 'gray' or 'minSW' (default is 'minSW')
    //  NOTE: this command does not move the arm; it must already be in the correct positions
    //      BUT it does configure the projectors
    case .takefull:
        let parameters = ["takefull", "projector", "position"]
        let usage = "usage: takefull [projector #] [position #]"
        // for now, simply tells prog where to save files
        let system: BinaryCodeSystem
        let systems: [String : BinaryCodeSystem] = ["gray" : .GrayCode, "minSW" : .MinStripeWidthCode]
        
        guard tokens.count >= parameters.count else {
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
        
        currentPos = position       // update current position
        
        currentProj = projector     // update current projector
        
        system = .MinStripeWidthCode

        let resolution: String
        if tokens.count >= 4 {
            resolution = tokens[3]
        } else {
            resolution = defaultResolution
        }
        
        displayController.switcher?.turnOff(0)   // turns off all projs
        print("Hit enter when all projectors off.")
        _ = readLine()  // wait until user hits enter
        displayController.switcher?.turnOn(projector)
        print("Hit enter when selected projector ready.")
        _ = readLine()  // wait until user hits enter
        
        captureWithStructuredLighting(system: system, projector: projector, position: position, resolution: resolution)
        break
    
    // requests current lens position from iPhone camera, prints it
    case .readfocus:
        let packet = CameraInstructionPacket(cameraInstruction: .GetLensPosition)
        cameraServiceBrowser.sendPacket(packet)
//        photoReceiver.receiveLensPosition(completionHandler: { (pos: Float) in
//            print("Lens position:\t\(pos)")
//            processingCommand = false
//        })
        photoReceiver.dataReceiver = LensPositionReceiver { (pos: Float) in
            print("Lens position:\t\(pos)")
            processingCommand = false
        }
        
    // tells the iPhone to use the 'auto focus' focus mode
    case .autofocus:
        _ = setLensPosition(-1.0)
        processingCommand = false
    
    // tells the iPhone to lock the focus at the current position
    case .lockfocus:
        let packet = CameraInstructionPacket(cameraInstruction: .LockLensPosition)
        cameraServiceBrowser.sendPacket(packet)
//        photoReceiver.receiveLensPosition(completionHandler: { (pos: Float) in
//            print("Lens position:\t\(pos)")
//            processingCommand = false
//        })
//        var done = false
        photoReceiver.receiveLensPositionSync()
//        while !done {}
        
    // tells the iPhone to set the focus to the given lens position & lock the focus
    case .setfocus:
        guard nextToken < tokens.count else {
            print("usage: setfocus [lensPosition] (0.0 <= lensPosition <= 1.0)")
            break
        }
        guard let pos = Float(tokens[nextToken]) else {
            print("ERROR: Could not parse float value for lens position.")
            break
        }
        _ = setLensPosition(pos)
        processingCommand = false
    
    // autofocus on point, given in normalized x and y coordinates
    // NOTE: top left corner of image frame when iPhone is held in landscape with home button on the right corresponds to (0.0, 0.0).
    case .focuspoint:
        // arguments: x coord then y coord (0.0 <= 1.0, 0.0 <= 1.0)
        guard tokens.count >= 3 else {
            print("usage: focuspoint [x_coord] [y_coord]")
            break
        }
        guard let x = Float(tokens[1]), let y = Float(tokens[2]) else {
            print("invalid x or y coordinate: must be on interval [0.0, 1.0]")
            break
        }
        let point = CGPoint(x: CGFloat(x), y: CGFloat(y))
        let packet = CameraInstructionPacket(cameraInstruction: .SetPointOfFocus, pointOfFocus: point)
        cameraServiceBrowser.sendPacket(packet)
//        photoReceiver.receiveLensPosition(completionHandler: { (_: Float) in
//                processingCommand = false
//        })
        photoReceiver.receiveLensPositionSync()
        break
        
    // currently useless, but leaving in here just in case it ever comes in handy
    case .lockwhitebalance:
        let packet = CameraInstructionPacket(cameraInstruction: .LockWhiteBalance)
        cameraServiceBrowser.sendPacket(packet)
        var receivedUpdate = false
//        photoReceiver.receiveStatusUpdate(completionHandler: {(update: CameraStatusUpdate) in receivedUpdate = true})
        photoReceiver.dataReceiver = StatusUpdateReceiver { (update: CameraStatusUpdate) in
            receivedUpdate = true
        }
        while !receivedUpdate {}
        
    // tells iPhone to use auto exposure mode (automatically adjusts exposure)
    case .autoexposure:
        let packet = CameraInstructionPacket(cameraInstruction: .AutoExposure)
        cameraServiceBrowser.sendPacket(packet)
    
    // tells iPhone to use locked exposure mode (does not change exposure settings, even when lighting
    //   changes)
    case .lockexposure:
        let packet = CameraInstructionPacket(cameraInstruction: .LockExposure)
        cameraServiceBrowser.sendPacket(packet)
    
    // displays checkerboard pattern
    // optional parameter: side length of squares, in pixels
    case .cb:
        let usage = "usage: cb [squareSize]?"
        let size: Int
        guard tokens.count >= 1 && tokens.count <= 2 else {
            print(usage)
            break
        }
        if tokens.count == 2 {
            size = Int(tokens[nextToken]) ?? 2
        } else {
            size = 2
        }
        displayController.currentWindow?.displayCheckerboard(squareSize: size)
        //displayController.windows.first!.displayCheckerboard(squareSize: size)
        break
    
    // paints entire window black
    case .black:
        displayController.currentWindow?.displayBlack()
        //displayController.windows.first!.displayBlack()
        break
       
    // paints entire window white
    case .white:
        displayController.currentWindow?.displayWhite()
        //displayController.windows.first!.displayWhite()
        break
    
    // displays diagonal stripes (at 45°) of specified width (measured horizontally)
    // (tool for testing pico projector and its diagonal pixel grid)
    case .diagonal:
        let usage = "usage: diagonal [stripe width]"    // width measured horizontally
        guard tokens.count == 2, let stripeWidth = Int(tokens[1]) else {
            print(usage)
            break
        }
        displayController.currentWindow?.displayDiagonal(width: stripeWidth)
        break
    
    // displays vertical bars of specified width
    // (tool originaly made for testing pico projector)
    case .verticalbars:
        let usage = "usage: verticalbars [width]"
        guard tokens.count == 2, let stripeWidth = Int(tokens[1]) else {
            print(usage)
            break
        }
        displayController.currentWindow?.displayVertical(width: stripeWidth)
        break
       
    // moves linear robot arm to specified position using VXM controller box
    //   *the specified position can be either an integer or 'MIN'/'MAX', where 'MIN' resets the arm
    //      (and zeroes out the coordinate system)*
    case .movearm:
        switch tokens.count {
        case 2:
            let posStr: String
            if let posID = Int(tokens[1]) {
                posStr = positions[posID]
            } else if tokens[1].hasPrefix("p[") && tokens[1].hasSuffix("]") {
                posStr = tokens[1]
            } else {
                print("movearm: \(tokens[1]) is not a valid position string or index.")
                break
            }
            print("Moving arm to position \(posStr)")
            var cStr = posStr.cString(using: .ascii)!
            DispatchQueue.main.async {
                MovePose(&cStr, 0, 0)  // use default acceleration & velocities
                print("Moved arm to position \(posStr)")
            }
        case 3:
            guard let ds = Float(tokens[2]) else {
                print("movearm: \(tokens[2]) is not a valid distance.")
                break
            }
            switch tokens[1] {
            case "x":
                DispatchQueue.main.async {
                    MoveLinearX(ds, 0, 0)
                }
            case "y":
                DispatchQueue.main.async {
                    MoveLinearY(ds, 0, 0)
                }
            case "z":
                DispatchQueue.main.async {
                    MoveLinearZ(ds, 0, 0)
                }
            default:
                print("moevarm: \(tokens[1]) is not a recognized direction.")
            }
            
        default:
            print("usage: \(commandUsage[.movearm]!)")
            break
        }
        
        break
    
    case .addpos:
        switch tokens.count {
        case 2:
            positions.append(tokens[1]) // append pos string
        case 3:
            guard let posID = Int(tokens[2]), posID <= positions.count && posID >= 0 else {
                print("addpos: invalid position ID.")
                break
            }
            if (posID == positions.count) { positions.append( tokens[1] ) }
            else { positions[posID] = tokens[1] }
        default:
            print("usage: \(commandUsage[.addpos]!)")
        }
        
    
    // used to turn projectors on or off
    //  -argument 1: either projector # (1–8) or 'all', which addresses all of them at once
    //  -argument 2: either 'on', 'off', '1', or '0', where '1' turns the respective projector(s) on
    // NOTE: the Kramer switcher box must be connected (use 'connect switcher' command), of course
    case .proj:
        guard tokens.count == 3 else {
            print("usage: proj [projector_#|all] [on|off]|[1|0]")
            break
        }
        if let projector = Int(tokens[1]) {
            switch tokens[2] {
            case "on", "1":
                displayController.switcher?.turnOn(projector)
                currentProj = projector
            case "off", "0":
                displayController.switcher?.turnOff(projector)
                currentProj = -1
            default:
                print("Unrecognized argument: \(tokens[2])")
            }
        } else if tokens[1] == "all" {
            currentProj = -1
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
        
    // refines decoded PFM image with given name (assumed to be located in the decoded subdirectory)
    //  and saves intermediate and final results to refined subdirectory
    //    -direction argument specifies which axis to refine in, where 0 <-> x-axis
    // TO-DO: this does not take advantage of the ideal direction calculations performed at the new smart
    //  thresholding step
    case .refine:
        let params = ["refine", "proj", "pos", "direction"]
        let usage = "usage: refine [proj #] [pos #] [direction [0,1]]"
        guard tokens.count == params.count else {
            print(usage)
            break
        }
        guard let proj = Int(tokens[1]) else {
            print("refine: error - improper projector number \(tokens[1])")
            break
        }
        guard let pos = Int(tokens[2]) else {
            print("refine: error - improper position number \(tokens[2])")
            break
        }
        guard let direction = Int32(tokens[3]) else {
            print("refine: error - improper direction \(tokens[3])")
            break
        }
        let imgpath: String = dirStruc.decodedFile(Int(direction), proj: proj, pos: pos) //[scenesDirectory, sceneName, computedSubdir, decodedSubdir, "proj\(proj)", "pos\(pos)", "result\(direction).pfm"].joined(separator: "/")
        let outdir: String = dirStruc.subdir(dirStruc.refined, proj: proj, pos: pos)//[scenesDirectory, sceneName, computedSubdir, refinedSubdir, "proj\(proj)", "pos\(pos)"].joined(separator: "/")
        let metadatapath = dirStruc.metadataFile(Int(direction), proj: proj, pos: pos)
        do {
            let metadataStr = try String(contentsOfFile: metadatapath)
            let metadata: Yaml = try Yaml.load(metadataStr)
            if let angle: Double = metadata.dictionary?["angle"]?.double {
                refineDecodedIm(swift2Cstr(outdir), direction, swift2Cstr(imgpath), angle)
            }
        } catch {
            print("refine error: could not load metadata file \(metadatapath).")
        }
        break
    
    // computes disparity maps from decoded & refined images; saves them to 'disparity' directories
    // usage options:
    //  -'disparity': computes disparities for all projectors & all consecutive positions
    //  -'disparity [projector #]': computes disparities for given projectors for all consecutive positions
    //  -'disparity [projector #] [leftPos] [rightPos]': computes disparity map for single viewpoint pair for specified projector
    //
    // NOTE: these disparity maps are not yet rectified
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
    
    case .rectify:
        let usage = "usage: rectify [proj #] [leftpos] [rightpos]"
        guard tokens.count == 4, let proj = Int(tokens[1]), let left = Int(tokens[2]), let right = Int(tokens[3]) else {
            print(usage)
            break
        }
        rectify(left: left, right: right, proj: proj)
        break
        
        
    // calculates camera's intrinsics using chessboard calibration photos in orig/calibration/chessboard
    // TO-DO: TEMPLATE PATHS SHOULD BE COPIED TO SAME DIRECTORY AS MAC EXECUTABLE SO
        // ABSOLUTE PATHS NOT REQUIRED
    case .getintrinsics:
        let imgsdir = scenesDirectory+"/"+sceneName+"/"+origSubdir+"/"+calibSubdir+"/"+"chessboard"
        let imglistdir = scenesDirectory+"/"+sceneName+"/"+settingsSubdir+"/"+calibSettingsSubdir+"/"+"imageLists"
        /*
        do {
            try createImageList(fromDir: imgsdir, toPath: imglistdir+"/singleChessboard.xml")
        } catch {
            print("getintrinsics: error - could not create image list.")
        }
 
        let templatepath: String = "/Users/nicholas/OneDrive - Middlebury College/Summer Research 2017/MobileLighting/MobileLighting/MobileLighting_Mac/cameraCalib/settings/settingsIntrinsicChessboard.xml"
        
        let imglistpath: String = imglistdir+"/"+"singleChessboard.xml"
        let settingsdir: String = scenesDirectory+"/"+sceneName+"/"+settingsSubdir+"/"+calibSettingsSubdir+"/settings"
        let settingspath = settingsdir+"/settingsIntrinsicChessboard.yml"
        
        createSettingsIntrinsitcsChessboard(swift2Cstr(settingspath), swift2Cstr(imglistpath), swift2Cstr(templatepath))
        DispatchQueue.main.async {
            calibrateWithSettings(swift2Cstr(settingspath))
        }
        */
    
    // displays current resolution being used for external display
    // -useful for troubleshooting with projector display issues
    case .dispres:
        let screen = displayController.currentWindow!
        print("Screen resolution: \(screen.width)x\(screen.height)")
    
    // displays a min stripe width binary code pattern
    //  useful for verifying the minSW.dat file loaded properly
    case .dispcode:
        displayController.currentWindow!.displayBinaryCode(forBit: 0, system: .MinStripeWidthCode)
    }
    
    return true
}



//MARK: SETUP/CAPTURE ROUTINES + UTILITY FUNCTIONS

// setLensPosition
// -Parameters
//      - lensPosition: Float -> what to set the camera's lens position to
// -Return value: Float -> camera's lens position directly after done adjusting focus
// NOTE: return value seems to be inaccurate - just ignore it for now
func setLensPosition(_ lensPosition: Float) -> Float {
    let packet = CameraInstructionPacket(cameraInstruction: .SetLensPosition, lensPosition: lensPosition)
    cameraServiceBrowser.sendPacket(packet)
    var lensPos = photoReceiver.receiveLensPositionSync()
    return lensPos
}


// captureWithStructuredLighting - does a 'full take' of current scene using the specified binary code system.
//   - system: BinaryCodeSystem - either GrayCode or MinStripeWidthCode
//   - projector: Int - should be in range [1, 8] (if using Kramer switcher box). Currently does
//       not turn on projector; the value is used for only creating/saving to the proper directory
//   - position: Int - should be >= 0, less than total # of positions (currently only 2)
//       Doesn't move to the position; simply uses value for saving to proper directory
//  NOTE: before calling this function, be sure that the correct projector is on and properly configured.
//      (Sometimes the ViewSonic projectors will take a while to display video input after being switched
//      on from the Kramer box.)
func captureWithStructuredLighting(system: BinaryCodeSystem, projector: Int, position: Int, resolution: String) {
    var currentCodeBit: Int
    let codeBitCount: Int = 10
    var horizontal = false
    let decodedDir = dirStruc.subdir(dirStruc.decoded, proj: projector, pos: position)
    var packet: CameraInstructionPacket
    
    var done: Bool = false
    
    // create decoded directory if necessary
    do {
        try FileManager.default.createDirectory(atPath: decodedDir, withIntermediateDirectories: true, attributes: nil)
    } catch { fatalError("Failed to create directory at \(decodedDir).") }
    
    // DESCRIPTION OF FLOW OF EXECUTION
    //   There are two different subfunctions that drive the capture of the scene. They are:
    //      -captureNextBinaryCode() -> Void
    //      -captureInvertedBinaryCode(CameraStatusUpdate) -> Void
    //  
    //   captureBinaryCode() is the entry point to the chain of calls that follows the initial setup 
    //     performed at the top level of enclosing function. It displays the correct binary code image
    //     with the correct orientation and notifies the iPhone that it should begin capturing for the
    //     current binary code bit being displayed. It then tells the photo receiver to receive a status
    //     update from the iPhone, setting the completion handler (which is called on receipt of the
    //     update) to be the captureInvertedBinaryCode() function.
    //
    //   captureInvertedBinaryCode() is called after the iPhone has notified the Mac that it has finished
    //      taking a photo of the non-inverted binary code image. The function then displays the inverted
    //      image of the current binary code; it then notifies the iPhone that it should take a picture 
    //      of an inverted binary code image. This time, instead of a status update, it tells the photo 
    //      receiver to expect two images - one prethresholded intensity difference image and one 
    //      thresholded image - and save them to the 'tmp' directory (ultimately, this part of the image 
    //      processing will only take place on the iPhone). After incrementing the current binary code 
    //      bit, the photo receiver will then call captureBinaryCode(), starting the loop all over again
    func captureNextBinaryCode() {
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
        
        // configure capture of normal photo bracket for current code bit
        displayController.configureDisplaySettings(horizontal: horizontal, inverted: false)
        displayController.displayBinaryCode(forBit: currentCodeBit, system: system)
        
        let packet = CameraInstructionPacket(cameraInstruction: CameraInstruction.CaptureNormalInvertedPair, resolution: resolution, photoBracketExposureDurations: exposureDurations, binaryCodeBit: currentCodeBit, photoBracketExposureISOs: exposureISOs)
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + monitorTimeDelay) {
            cameraServiceBrowser.sendPacket(packet)
            photoReceiver.dataReceiver = StatusUpdateReceiver( { (_ update: CameraStatusUpdate) in captureInvertedBinaryCode(statusUpdate: update)})
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
        displayController.displayBinaryCode(forBit: currentCodeBit, system: system)
        let packet = CameraInstructionPacket(cameraInstruction: CameraInstruction.FinishCapturePair, resolution: resolution, photoBracketExposureDurations: exposureDurations, binaryCodeBit: currentCodeBit, photoBracketExposureISOs: exposureISOs)
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + monitorTimeDelay) {
            cameraServiceBrowser.sendPacket(packet)
            
            
            if (shouldSendThreshImgs) {
                let direction = horizontal ? 1 : 0
                let prethreshpath = dirStruc.subdir(dirStruc.prethresh)
                let threshpath = dirStruc.subdir(dirStruc.thresh)
                let handler2 = captureNextBinaryCode
                let handler1 = {
                    photoReceiver.dataReceiver = CalibrationImageReceiver(handler2, dir: "tmp/thresh/\(horizontal ? "h" : "v")", id: currentCodeBit-1)
                }
                //MARK: NEED TO FIX THIS AFTER HANDLE PHOTO RECEIPT BETTER
                photoReceiver.dataReceiver = CalibrationImageReceiver(handler1, dir: "tmp/prethresh/\(horizontal ? "h" : "v")", id: currentCodeBit-1)
            } else {
                photoReceiver.dataReceiver = StatusUpdateReceiver { (update: CameraStatusUpdate) in
                    captureNextBinaryCode()
                }
            }
      
            currentCodeBit += 1
        }
    }
    
    horizontal = false
    currentCodeBit = 0  // reset to 0
    
    packet = CameraInstructionPacket(cameraInstruction: .StartStructuredLightingCaptureFull, resolution: resolution, binaryCodeDirection: !horizontal, binaryCodeSystem: system)
    cameraServiceBrowser.sendPacket(packet)
    while !cameraServiceBrowser.readyToSendPacket {}
    
    captureNextBinaryCode()
    while currentCodeBit < codeBitCount || !done {}  // wait til finished
    
    packet = CameraInstructionPacket(cameraInstruction: .EndStructuredLightingCaptureFull)
    cameraServiceBrowser.sendPacket(packet)
//    photoReceiver.receiveDecodedImage(horizontal: false, completionHandler: {path in decodedImageHandler(path, horizontal: false, projector: projector, position: position)}, absDir: decodedDir)
    var received = false
    var completionHandler = { (path: String) in
        received = true
        decodedImageHandler(path, horizontal: false, projector: projector, position: position)
    }
    photoReceiver.dataReceiver = DecodedImageReceiver(completionHandler, dir: decodedDir, horizontal: false)
    while !received || !cameraServiceBrowser.readyToSendPacket {}
    
    displayController.configureDisplaySettings(horizontal: true, inverted: false)
    currentCodeBit = 0
    horizontal = true
    
    packet = CameraInstructionPacket(cameraInstruction: .StartStructuredLightingCaptureFull, resolution: resolution, binaryCodeDirection: !horizontal, binaryCodeSystem: system)
    cameraServiceBrowser.sendPacket(packet)
    while !cameraServiceBrowser.readyToSendPacket {}
    
    captureNextBinaryCode()
    while currentCodeBit < codeBitCount || !done {}
    
    packet = CameraInstructionPacket(cameraInstruction: .EndStructuredLightingCaptureFull)
    cameraServiceBrowser.sendPacket(packet)
//    photoReceiver.receiveDecodedImage(horizontal: true, completionHandler: {path in decodedImageHandler(path, horizontal: true, projector: projector, position: position)}, absDir: decodedDir)
    received = false
    completionHandler = { (path: String) in
        received = true
        decodedImageHandler(path, horizontal: true, projector: projector, position: position)
    }
    photoReceiver.dataReceiver = DecodedImageReceiver(completionHandler, dir: decodedDir, horizontal: true)
    while !received || !cameraServiceBrowser.readyToSendPacket {}
}


// captureStereoCalibration: captures specified number of image pairs from specified linear robot arm positions
//   -left arm position should be greater (i.e. farther from 0 on robot arm) than right arm position
//   -requires user input to indicate when robot arm has finished moving to position
//   -minimizes # of robot arm movements required
//   -stores images in 'left' and 'right' folders of 'calibration' subdir (under 'orig')
func captureStereoCalibration(left pos0: Int, right pos1: Int, nPhotos: Int, resolution: String = "high") {
    let packet = CameraInstructionPacket(cameraInstruction: .CaptureStillImage, resolution: resolution)
    var receivedCalibrationImage: Bool = false
    let completionHandler = {
        receivedCalibrationImage = true
    }
    let msgMove = "Hit enter when camera in position."
    let msgBoard = "Hit enter when board repositioned."
    let leftSubdir = dirStruc.stereoPhotosPairLeft(left: pos0, right: pos1) //dirStruc.calibrationPos(pos0)
    let rightSubdir = dirStruc.stereoPhotosPairRight(left: pos0, right: pos1)//dirStruc.calibrationPos(pos1)
    
    
    // in the future, should set autoexposure & autofocus
    //var packet2 = CameraInstructionPacket(cameraInstruction: .AutoExposure)
    //cameraServiceBrowser.sendPacket(packet2)
    //packet2 = CameraInstructionPacket(cameraInstruction: )
    
    Restore()
    
    func wait() -> Bool {
        while true {
            let inputo: String? = readLine()
            guard let input = inputo else {
                return true  // wait until blank line, should continue
            }
            if let pos = Int(input) {
                if pos%2 == 0 {
                    Restore()
                } else {
                    Next()
                }
            } else if ["quit", "stop", "end", "exit"].contains(input) {
                return false
            } else {
                return true
            }
        }
    }
    guard wait() else { return }
    print(msgMove)
    cameraServiceBrowser.sendPacket(packet)
    receivedCalibrationImage = false
    photoReceiver.dataReceiver = CalibrationImageReceiver(completionHandler, dir: rightSubdir, id: 0)
    while !receivedCalibrationImage {}
    
    for i in 0..<nPhotos-1 {
        if i%2 == 0 {
            Next()
        } else {
            Restore()
        }
        let subpath = (i%2 == 0) ? leftSubdir:rightSubdir
        print(msgMove)
        guard wait() else { return }
//        _ = readLine() // operator must press enter when in position; also signal to take photo
        cameraServiceBrowser.sendPacket(packet)
        receivedCalibrationImage = false
        photoReceiver.dataReceiver = CalibrationImageReceiver(completionHandler, dir: subpath, id: i)
        while !receivedCalibrationImage {}
        
        print(msgBoard)
//        _ = readLine()
        guard wait() else { return }
        cameraServiceBrowser.sendPacket(packet)
        receivedCalibrationImage = false
        photoReceiver.dataReceiver = CalibrationImageReceiver(completionHandler, dir: subpath, id: i+1)
        while !receivedCalibrationImage {}
    }
    
    
    if (nPhotos%2 == 0) {
        Restore()
    } else {
        Next()
    }
    guard wait() else { return }

    
    print(msgMove)
//    _ = readLine()
    cameraServiceBrowser.sendPacket(packet)
    receivedCalibrationImage = false
    photoReceiver.dataReceiver = CalibrationImageReceiver(completionHandler, dir: (nPhotos%2 == 0) ? rightSubdir:leftSubdir, id: nPhotos-1)
    while !receivedCalibrationImage {}
}



// creates the camera service browser (for sending instructions to iPhone) and
//    the photo receiver (for receiving photos, updates, etc from iPhone)
// NOTE: returns immediately; doens't wait for connection with iPhone to be established.
func initializeIPhoneCommunications() {
    cameraServiceBrowser = CameraServiceBrowser()
    photoReceiver = PhotoReceiver(scenesDirectory)
    
    photoReceiver.startBroadcast()
    cameraServiceBrowser.startBrowsing()
}

// waits for both photo receiver & camera service browser communications
// to be established (synchronous)
// NOTE: only call if you're sure it won't seize control of the program / cause it to hang
//    e.g. it should be executed within a DispatchQueue
func waitForEstablishedCommunications() {
    while !cameraServiceBrowser.readyToSendPacket {}
    while !photoReceiver.readyToReceive {}
}

// configures the display controller object, whcih manages the displays
// untested for multiple screens; Kramer switcher box is treated as only one screen
func configureDisplays() -> Bool {
    if displayController == nil {
        displayController = DisplayController()
    }
    guard NSScreen.screens()!.count > 1  else {
        print("Only one screen connected.")
        return false
    }
    for screen in NSScreen.screens()! {
        if screen != NSScreen.main()! {
            displayController.createNewWindow(on: screen)
        }
    }
    return true
}
