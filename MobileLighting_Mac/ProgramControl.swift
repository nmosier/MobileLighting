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
    
    case struclight
    case takeamb
    
    // camera settings
    case readfocus, autofocus, setfocus, lockfocus
    case readexposure, autoexposure, lockexposure, setexposure
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
    case rectify
    case disparity
    case merge
    case reproject
    case merge2
    
    // camera calibration
    case calibrate  // 'x'
    case calibrate2pos
    case stereocalib
    case getintrinsics
    case getextrinsics
    
    // take ambient photos
    
    // for debugging
    case dispres
    case dispcode
    case clearpackets
    
    // for scripting
    case sleep
    
}

let commandUsage: [Command : String] = [
    .help: "help",
    .quit: "quit",
    .reloadsettings: "reloadsettings [attribute_name]",
    .connect: "connect [iphone|switcher|vxm] [port string]?",
    .disconnect: "disconnect [vxm|switcher]",
    .calibrate: "calibrate [# of photos]",
    .calibrate2pos: "calibrate2pos [leftPos: Int] [rightPos: Int] [photosCountPerPos: Int] [resolution]?",
    .struclight: "struclight [projector #] [position #] [code system]?",
    .takeamb: "takeamb (still | video) [nPhotos]?",
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
    .getintrinsics: "getintrinsics [board_type = ARUCO_SINGLE]",
    .getextrinsics: "getextrinsics [leftpos] [rightpos] [board_type = ARUCO_SINGLE"
]


var processingCommand: Bool = false

// nextCommand: prompts for next command at command line, then handles command
// -Return value -> true if program should continue, false if should exit
func nextCommand() -> Bool {
    guard let input = readLine(strippingNewline: true) else {
        // if input empty, simply return & continue execution
        return true
    }
    return processCommand(input)
}

func processCommand(_ input: String) -> Bool {
    var nextToken = 0
    let tokens: [String] = input.split(separator: " ").map{ return String($0) }
    guard let command = Command(rawValue: tokens.first ?? "") else { // "" is invalid token, automatically rejected
        // if input contains no valid commands, return
        return true
    }
    
    processingCommand = true
    
    nextToken += 1
    cmdSwitch: switch command {
    case .help:
        // to be implemented
        for (command, usage) in commandUsage {
            print("\(command):\t\(usage)")
        }
        print()
        
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
        
        let sceneSettings: SceneSettings
        do {
            sceneSettings = try SceneSettings(sceneSettingsPath)
            print("Successfully loaded initial settings.")
        } catch {
            print("Fatal error: could not load init settings")
            break
        }
        
        if tokens[1] == "exposures" {
            print("Reloading exposures...")
            strucExposureDurations = sceneSettings.strucExposureDurations
            print("New exposures: \(strucExposureDurations)")
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
        guard tokens.count == 2 || tokens.count == 3 else {
            print("usage: calibrate [-d|-a]? [# of photos]\n       -d -- delete existing photos\n       -a -- append to existing photos")
            break
        }
        
        if calibrationExposure != (0, 0) {
            let packet = CameraInstructionPacket(cameraInstruction: .SetExposure, photoBracketExposureDurations: [calibrationExposure.0], photoBracketExposureISOs: [calibrationExposure.1])
            cameraServiceBrowser.sendPacket(packet)
        }
        
        let nPhotos: Int
        let startIndex: Int
        if tokens.count == 3 {
            let mode = tokens[1]
            guard ["-d","-a"].contains(mode) else {
                print("calibrate: unrecognized flag \(mode)")
                break
            }
            guard let n = Int(tokens[2]) else {
                print("calibrate: invalid number of photos \(tokens[2])")
                break
            }
            nPhotos = n
            var photos = (try! FileManager.default.contentsOfDirectory(atPath: dirStruc.intrinsicsPhotos)).map {
                return "\(dirStruc.intrinsicsPhotos)/\($0)"
            }
            switch mode {
            case "-d":
                for photo in photos {
                    do { try FileManager.default.removeItem(atPath: photo) }
                    catch { print("could not remove \(photo)") }
                }
                startIndex = 0
            case "-a":
                photos = photos.map{
                    return String($0.split(separator: "/").last!)
                }
                let ids: [Int] = photos.map{
                    guard $0.hasPrefix("IMG"), $0.hasSuffix(".JPG"), let id = Int($0.dropFirst(3).dropLast(4)) else {
                        return -1
                    }
                    return id
                }
                startIndex = ids.max()! + 1
            default:
                startIndex = 0
            }
        } else {
            guard let n = Int(tokens[1]) else {
                print("calibrate: invalid number of photos \(tokens[2])")
                break
            }
            nPhotos = n
            startIndex = 0
        }
        let packet = CameraInstructionPacket(cameraInstruction: .CaptureStillImage, resolution: defaultResolution)
        let subpath = dirStruc.intrinsicsPhotos
            for i in startIndex..<(nPhotos+startIndex) {
                print("Hit enter to take photo.")
                guard let input = readLine() else {
                    fatalError("Unexpected error in reading stdin.")
                }
                if ["exit", "quit", "stop"].contains(input) {
                    break
                }
                
                // take calibration photo
                var receivedCalibrationImage = false
                cameraServiceBrowser.sendPacket(packet)
                let completionHandler = { receivedCalibrationImage = true }
                photoReceiver.dataReceivers.insertFirst(
                    CalibrationImageReceiver(completionHandler, dir: subpath, id: i)
                )
                while !receivedCalibrationImage {}
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
        
        if calibrationExposure != (0, 0) {
            let packet = CameraInstructionPacket(cameraInstruction: .SetExposure, photoBracketExposureDurations: [calibrationExposure.0], photoBracketExposureISOs: [calibrationExposure.1])
            cameraServiceBrowser.sendPacket(packet)
        }
        
        let resolution = (tokens.count == 5) ? tokens[4] : defaultResolution   // high is default res
        captureStereoCalibration(left: left, right: right, nPhotos: nPhotos, resolution: resolution)
        break
        
    case .stereocalib:
        let usage = "usage: stereocalib [nPhotos: Int] [resolution]?"
        guard tokens.count > 1 else {
            print(usage)
            break
        }
        guard let nPhotos = Int(tokens[1]) else {
            print(usage)
            break
        }
        
        if calibrationExposure != (0, 0) {
            let packet = CameraInstructionPacket(cameraInstruction: .SetExposure, photoBracketExposureDurations: [calibrationExposure.0], photoBracketExposureISOs: [calibrationExposure.1])
            cameraServiceBrowser.sendPacket(packet)
        }
        
        let posIDs = [Int](0..<positions.count)
        if tokens.count == 2 {
            captureNPosCalibration(posIDs: posIDs, nPhotos: nPhotos)
        } else {
            captureNPosCalibration(posIDs: posIDs, nPhotos: nPhotos, resolution: tokens[2])
        }
    
    // captures scene using structured lighting from specified projector and position number
    // - code system to use is an optional parameter: can either be 'gray' or 'minSW' (default is 'minSW')
    //  NOTE: this command does not move the arm; it must already be in the correct positions
    //      BUT it does configure the projectors
    case .struclight:
//        let parameters = ["struclight", "projector", "position"]
        let usage = "usage: struclight [id] [projector #] [position #] [resolution]?"
        // for now, simply tells prog where to save files
        let system: BinaryCodeSystem
//        let systems: [String : BinaryCodeSystem] = ["gray" : .GrayCode, "minSW" : .MinStripeWidthCode]
        
        guard tokens.count >= 4 else {
            print(usage)
            break
        }
        guard let projPos = Int(tokens[1]) else {
            print("struclight: invalid projector position number")
            break
        }
        guard let projID = Int(tokens[2]) else {
            print("struclight: invalid projector id.")
            break
        }
        guard let armPos = Int(tokens[3]) else {
            print("struclight: invalid position number \(tokens[2]).")
            break
        }
        guard armPos >= 0, armPos < positions.count else {
            print("struclight: position \(armPos) out of range.")
            break
        }
        
        currentPos = armPos       // update current position
        
        currentProj = projPos     // update current projector
        
        system = .MinStripeWidthCode

        let resolution: String
        if tokens.count == 5 {
            resolution = tokens[4]
        } else {
            resolution = defaultResolution
        }
        
        displayController.switcher?.turnOff(0)   // turns off all projs
        print("Hit enter when all projectors off.")
        _ = readLine()  // wait until user hits enter
        displayController.switcher?.turnOn(projID)
        print("Hit enter when selected projector ready.")
        _ = readLine()  // wait until user hits enter
        
        var pose = *positions[armPos]
        MovePose(&pose, robotVelocity, robotAcceleration)
        usleep(UInt32(robotDelay * 1.0e6))
        
        captureWithStructuredLighting(system: system, projector: projPos, position: armPos, resolution: resolution)
        break
    
        
    case .takeamb:
        let usage = "usage: takeamb (still|video) [nPhotos]? [resolution]?"
        let (params, flags) = partitionTokens([String](tokens[1...]))
        
        guard params.count > 0 else {
            print(usage)
            break
        }
        switch params[0] {
        case "still":
            
            guard params.count >= 2, let nPhotos = Int(params[1]) else {
                print("usage: takeamb still [nPhotos] [resolution]?")
                break cmdSwitch
            }
            
            let resolution: String
            if params.count == 3 {
                resolution = params[2]
            } else {
                resolution = defaultResolution
            }
            
//            print(resolution)
//            print(sceneSettings.ambientExposureISOs)
//            print(sceneSettings.ambientExposureDurations)
            let packet = CameraInstructionPacket(cameraInstruction: .CapturePhotoBracket, resolution: resolution, photoBracketExposureDurations: sceneSettings.ambientExposureDurations, photoBracketExposureISOs: sceneSettings.ambientExposureISOs)
            
            for pos in 0..<positions.count {
                var posStr = *positions[pos]
                MovePose(&posStr, robotAcceleration, robotVelocity)
                print("Hit enter when camera in position.")
                _ = readLine()
                
                // take photo bracket
                cameraServiceBrowser.sendPacket(packet)
                
                var nReceived = 0
                let completionHandler = { nReceived += 1 }
                for exp in 0..<sceneSettings.ambientExposureDurations!.count {
                    let path = dirStruc.ambientPhotos(pos: pos, exp: exp) + "/IMG\(exp).JPG"
                    let ambReceiver = AmbientImageReceiver(completionHandler, path: path)
                    photoReceiver.dataReceivers.insertFirst(ambReceiver)
                }
                while nReceived != sceneSettings.ambientExposureDurations!.count {}
                // continue
            }
            
            // AmbientImageReceiver
            
            break
        case "video":
            guard params.count >= 1, params.count <= 2 else {
                print(usage)
                break cmdSwitch
            }
            
            let exp: Int
            if params.count == 1 {
                exp = 0
            } else {
                guard let exp_ = Int(tokens[1]) else {
                    print("takeamb video: invalid exposure number \(tokens[1])")
                    break cmdSwitch
                }
                exp = exp_
            }
            
            trajectory.moveToStart()
            print("takeamb video: hit enter when camera in position.")
            _ = readLine()
            
            print("takeamb video: starting recording...")
            var packet = CameraInstructionPacket(cameraInstruction: .StartVideoCapture)
            cameraServiceBrowser.sendPacket(packet)
            
            usleep(UInt32(0.5 * 1e6)) // wait 0.5 seconds
            
            // configure video data receiver
            let videoReceiver = AmbientVideoReceiver({}, path: "\(dirStruc.ambientVideos(exp))/video.mp4")
            photoReceiver.dataReceivers.insertFirst(videoReceiver)
            let imuReceiver = IMUDataReceiver({}, path: "\(dirStruc.ambientVideos(exp))/imu.yml")
            photoReceiver.dataReceivers.insertFirst(imuReceiver)
            
            trajectory.executeScript()
            print("takeamb video: hit enter when trajectory completed.")
            _ = readLine()
            packet = CameraInstructionPacket(cameraInstruction: .EndVideoCapture)
            cameraServiceBrowser.sendPacket(packet)
            print("takeamb video: stopping recording.")
            
            break
        default:
            break
        }
        
        break
        
        
        
    // requests current lens position from iPhone camera, prints it
    case .readfocus:
        let packet = CameraInstructionPacket(cameraInstruction: .GetLensPosition)
        cameraServiceBrowser.sendPacket(packet)
//        photoReceiver.receiveLensPosition(completionHandler: { (pos: Float) in
//            print("Lens position:\t\(pos)")
//            processingCommand = false
//        })
        photoReceiver.dataReceivers.insertFirst(
            LensPositionReceiver { (pos: Float) in
                print("Lens position:\t\(pos)")
                processingCommand = false
            }
        )
        
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
        _ = photoReceiver.receiveLensPositionSync()
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
        _ = photoReceiver.receiveLensPositionSync()
        break
        
    // currently useless, but leaving in here just in case it ever comes in handy
    case .lockwhitebalance:
        let packet = CameraInstructionPacket(cameraInstruction: .LockWhiteBalance)
        cameraServiceBrowser.sendPacket(packet)
        var receivedUpdate = false
//        photoReceiver.receiveStatusUpdate(completionHandler: {(update: CameraStatusUpdate) in receivedUpdate = true})
        photoReceiver.dataReceivers.insertFirst(
            StatusUpdateReceiver { (update: CameraStatusUpdate) in
                receivedUpdate = true
            }
        )
        while !receivedUpdate {}
    
    // tells iphone to send current exposure duration & ISO
    case .readexposure:
        let packet = CameraInstructionPacket(cameraInstruction: .ReadExposure)
        cameraServiceBrowser.sendPacket(packet)
        let completionHandler = { (exposure: (Double, Float)) -> Void in
            print("exposure duration = \(exposure.0), iso = \(exposure.1)")
        }
        photoReceiver.dataReceivers.insertFirst(ExposureReceiver(completionHandler))
        
    // tells iPhone to use auto exposure mode (automatically adjusts exposure)
    case .autoexposure:
        let packet = CameraInstructionPacket(cameraInstruction: .AutoExposure)
        cameraServiceBrowser.sendPacket(packet)
    
    // tells iPhone to use locked exposure mode (does not change exposure settings, even when lighting
    //   changes)
    case .lockexposure:
        let packet = CameraInstructionPacket(cameraInstruction: .LockExposure)
        cameraServiceBrowser.sendPacket(packet)
        
    case .setexposure:
        guard tokens.count == 3 else {
            print("usage: setexposure [exposureDuration] [exposureISO]\n       (set either parameter to 0 to leave unchanged)")
            break
        }
        guard let exposureDuration = Double(tokens[1]), let exposureISO = Float(tokens[2]) else {
            print("setexposure: invalid parameters \(tokens[1]), \(tokens[2])")
            break
        }
        let packet = CameraInstructionPacket(cameraInstruction: .SetExposure, photoBracketExposureDurations: [exposureDuration], photoBracketExposureISOs: [Double(exposureISO)])
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
                MovePose(&cStr, robotAcceleration, robotVelocity)  // use default acceleration & velocities
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
        let usage = "usage: refine [proj] [pos]\n       refine -a [pos]\n       refine -r [proj] [leftpos] [rightpos]\n       refine -a -r [leftpos] [rightpos]"
        guard tokens.count > 1 else {
            print(usage)
            break cmdSwitch
        }
        let (params, flags) = partitionTokens([String](tokens[1...]))
        var curParam = 0
        
        var rectified = false, all = false
        for flag in flags {
            switch flag {
            case "-r":
                rectified = true
            case "-a":
                all = true
            default:
                print("refine: invalid flag \(flag)")
                break cmdSwitch
            }
        }

        var projs = [Int]()
        if all {
            let projDirs = try! FileManager.default.contentsOfDirectory(atPath: dirStruc.decoded(rectified))
            projs = getIDs(projDirs, prefix: "proj", suffix: "")
        } else {
            guard let proj = Int(params[0]) else {
                print("refine: invalid projector \(params[0])")
                break
            }
            projs = [proj]
            curParam += 1
        }
//            guard let proj = Int(params[0]) else {
//                print("refine: invalid projector \(params[0])")
//                break
//            }

        for proj in projs {
            if !rectified {
                
                guard let pos = Int(params[curParam]) else {
                    print("refine: invalid position \(params[curParam])")
                    break
                }
                for direction: Int32 in [0, 1] {
                    var imgpath = *"\(dirStruc.decoded(proj: proj, pos: pos, rectified: false))/result\(pos)\(direction == 0 ? "u" : "v")-0initial.pfm"
                    var outdir = *dirStruc.decoded(proj: proj, pos: pos, rectified: false)
                    let metadatapath = dirStruc.metadataFile(Int(direction), proj: proj, pos: pos)
                    do {
                        let metadataStr = try String(contentsOfFile: metadatapath)
                        let metadata: Yaml = try Yaml.load(metadataStr)
                        if let angle: Double = metadata.dictionary?["angle"]?.double {
                            var posID = *"\(pos)"
                            refineDecodedIm(&outdir, direction, &imgpath, angle, &posID)
                        }
                    } catch {
                        print("refine error: could not load metadata file \(metadatapath).")
                    }
                }
            } else {
                
                guard let leftpos = Int(params[curParam]), let rightpos = Int(params[curParam+1]) else {
                    print("refine: invalid stereo positions \(params[curParam]), \(params[curParam+1])")
                    break
                }
                for direction: Int in [0, 1] {
                    for pos in [leftpos, rightpos] {
                        var cimg = *"\(dirStruc.decoded(proj: proj, pos: pos, rectified: true))/result\(leftpos)\(rightpos)\(direction == 0 ? "u" : "v")-0rectified.pfm"
                        var coutdir = *dirStruc.decoded(proj: proj, pos: pos, rectified: true)
                        
                        let metadatapath = dirStruc.metadataFile(Int(direction), proj: proj, pos: pos)
                        do {
                            let metadataStr = try String(contentsOfFile: metadatapath)
                            let metadata: Yaml = try Yaml.load(metadataStr)
                            if let angle: Double = metadata.dictionary?["angle"]?.double {
                                var posID = *"\(leftpos)\(rightpos)"
                                refineDecodedIm(&coutdir, Int32(direction), &cimg, angle, &posID)
                            }
                        } catch {
                            print("refine error: could not load metadata file \(metadatapath).")
                        }
                        
                    }
                }
            }
        }
        
    
    // computes disparity maps from decoded & refined images; saves them to 'disparity' directories
    // usage options:
    //  -'disparity': computes disparities for all projectors & all consecutive positions
    //  -'disparity [projector #]': computes disparities for given projectors for all consecutive positions
    //  -'disparity [projector #] [leftPos] [rightPos]': computes disparity map for single viewpoint pair for specified projector
    case .disparity:
        let usage = "usage: disparity [-r]? [-a | projector #] [left pos #] [right pos #]\n"
//        let flags = ["-r"]
        let (params, flags) = partitionTokens([String](tokens[1...]))
        var curParam = 0
        
        var rectified = false
        var all = false
        for flag in flags {
            switch flag {
            case "-r":
                rectified = true
            case "-a":
                all = true
            default:
                print("disparity: invalid flag \(flag)")
                break cmdSwitch
            }
        }
        if all {
            guard params.count == 2 else {
                print(usage)
                break
            }
        } else {
            guard params.count == 3 else {
                print(usage)
                break
            }
        }
        
        var projs = [Int]()
        if !all {
            guard let proj = Int(params[curParam]) else {
                print("disparity: invalid projector \(params[curParam])")
                break
            }
            projs = [proj]
            curParam += 1
        }
        guard let leftpos = Int(params[curParam]), let rightpos = Int(params[curParam+1]) else {
            print("disparity: invalid positions \(params[curParam]), \(params[curParam+1])")
            break
        }
        if all {
            let projDirs = try! FileManager.default.contentsOfDirectory(atPath: dirStruc.decoded(rectified))
            projs = getIDs(projDirs, prefix: "proj", suffix: "")
        }

        for proj in projs {
            disparityMatch(proj: proj, leftpos: leftpos, rightpos: rightpos, rectified: rectified)
        }
    
    case .rectify:
        let usage = "usage: rectify [flags...] [proj #] [leftpos] [rightpos]\n       rectify -a [leftpos] [rightpos]"
        let (params, flags) = partitionTokens([String](tokens[1...]))
        
        var all = false
        for flag in flags {
            switch flag {
            case "-a":
                all = true
            default:
                print("rectify: invalid flag \(flag)")
                break cmdSwitch
            }
        }
        
        if all {
            print(params.count)
            let projDirs = try! FileManager.default.contentsOfDirectory(atPath: dirStruc.decoded(false))
            let projIDs = getIDs(projDirs, prefix: "proj", suffix: "")
            
            guard params.count == 2, let left = Int(params[0]), let right = Int(params[1]) else {
                print(usage)
                break
            }
            
            for proj in projIDs {
                rectify(left: left, right: right, proj: proj)
            }
        } else {
            guard params.count == 3, let proj = Int(params[0]), let left = Int(params[1]), let right = Int(params[2]) else {
                print(usage)
                break
            }
            rectify(left: left, right: right, proj: proj)
        }
        
    case .merge:
        let usage = "usage: merge [flags...] [leftpos] [rightpos]\n       -r = rectified"
        guard tokens.count >= 3 else {
            print(usage)
            break
        }
        var curTok = 1
        let rectified: Bool
        if tokens[1] == "-r" {
            rectified = true
            curTok += 1
        } else {
            rectified = false
        }
        guard tokens.count == curTok + 2, let left = Int(tokens[curTok]), let right = Int(tokens[curTok+1]) else {
            print("merge: invalid stereo position pair provided.\n\(usage)")
            break
        }
        merge(left: left, right: right, rectified: rectified)
        
    case .reproject:
        let usage = "usage: reproject [leftpos] [rightpos]"
        guard tokens.count == 3 else {
            print(usage)
            break
        }
        
        guard let left = Int(tokens[1]), let right = Int(tokens[2]) else {
            print("reproject: invalid stereo position pair provided.")
            break
        }
        reproject(left: left, right: right)
        
    case .merge2:
        let usage = "usage: merge2 [leftpos] [rightpos]"
        guard tokens.count == 3 else {
            print(usage)
            break
        }
        guard let left = Int(tokens[1]), let right = Int(tokens[2]) else {
            print("reproject: invalid stereo position pair provided.")
            break
        }
        mergeReprojected(left: left, right: right)
        
    // calculates camera's intrinsics using chessboard calibration photos in orig/calibration/chessboard
    // TO-DO: TEMPLATE PATHS SHOULD BE COPIED TO SAME DIRECTORY AS MAC EXECUTABLE SO
        // ABSOLUTE PATHS NOT REQUIRED
    case .getintrinsics:
        guard tokens.count <= 2 else {
            print("usage: \(commandUsage[command])")
            break
        }
        let patternEnum: CalibrationSettings.CalibrationPattern
        if tokens.count == 1 {
            patternEnum = CalibrationSettings.CalibrationPattern.ARUCO_SINGLE
        } else {
            let pattern = tokens[1].uppercased()
            guard let patternEnumTemp = CalibrationSettings.CalibrationPattern(rawValue: pattern) else {
                print("getintrinsics: \(pattern) not recognized pattern.")
                break
            }
            patternEnum = patternEnumTemp
        }
        generateIntrinsicsImageList()
        let calib = CalibrationSettings(dirStruc.calibrationSettingsFile)
        calib.set(key: .Calibration_Pattern, value: Yaml.string(patternEnum.rawValue))
        calib.set(key: .Mode, value: Yaml.string(CalibrationSettings.CalibrationMode.INTRINSIC.rawValue))
        calib.set(key: .ImageList_Filename, value: Yaml.string(dirStruc.intrinsicsImageList))
        calib.set(key: .IntrinsicOutput_Filename, value: Yaml.string(dirStruc.intrinsicsYML))
        calib.save()
        var path = dirStruc.calibrationSettingsFile.cString(using: .ascii)!
        
        DispatchQueue.main.async {
            CalibrateWithSettings(&path)
        }
        break
    
    // do stereo calibration
    case .getextrinsics:
        guard tokens.count == 3 || tokens.count == 4 else {
            print("usage: \(commandUsage[command] ?? "")")
            break
        }
        guard let leftpos = Int(tokens[1]), let rightpos = Int(tokens[2]) else {
            print("getextrinsics: invalid positions \(tokens[1]), \(tokens[2])")
            break
        }
        let patternEnum: CalibrationSettings.CalibrationPattern
        if tokens.count == 3 {
            patternEnum = .ARUCO_SINGLE
        } else {
            guard let patternEnumTmp = CalibrationSettings.CalibrationPattern(rawValue: tokens[3]) else {
                print("getextrinsics: invalid board pattern \(tokens[3])")
                break
            }
            patternEnum = patternEnumTmp
        }
        generateStereoImageList(left: dirStruc.stereoPhotos(leftpos), right: dirStruc.stereoPhotos(rightpos))
        
        let calib = CalibrationSettings(dirStruc.calibrationSettingsFile)
        calib.set(key: .Calibration_Pattern, value: Yaml.string(patternEnum.rawValue))
        calib.set(key: .Mode, value: Yaml.string("STEREO"))
        calib.set(key: .ImageList_Filename, value: Yaml.string(dirStruc.stereoImageList))
        calib.set(key: .ExtrinsicOutput_Filename, value: Yaml.string(dirStruc.extrinsicsYML(left: leftpos, right: rightpos)))
        calib.save()
        
        DispatchQueue.main.async {
            var path = dirStruc.calibrationSettingsFile.cString(using: .ascii)!
            CalibrateWithSettings(&path)
        }
    
    // displays current resolution being used for external display
    // -useful for troubleshooting with projector display issues
    case .dispres:
        let screen = displayController.currentWindow!
        print("Screen resolution: \(screen.width)x\(screen.height)")
    
    // displays a min stripe width binary code pattern
    //  useful for verifying the minSW.dat file loaded properly
    case .dispcode:
        displayController.currentWindow!.displayBinaryCode(forBit: 0, system: .MinStripeWidthCode)
    
    // scripting
    case .sleep:
        let usage = "usage: sleep [secs: Float]"
        guard tokens.count == 2 else {
            print(usage)
            break
        }
        guard let secs = Double(tokens[1]) else {
            print("sleep: \(tokens[1]) not a valid number of seconds.")
            break
        }
        usleep(UInt32(secs * 1000000))
        
    case .clearpackets:
        photoReceiver.dataReceivers.removeAll()
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
    let decodedDir = dirStruc.decoded(proj: projector, pos: position, rectified: false) //dirStruc.subdir(dirStruc.decoded, proj: projector, pos: position)
    var packet: CameraInstructionPacket
    
    var imgpath: String
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
        
        let packet = CameraInstructionPacket(cameraInstruction: CameraInstruction.CaptureNormalInvertedPair, resolution: resolution, photoBracketExposureDurations: strucExposureDurations, binaryCodeBit: currentCodeBit, photoBracketExposureISOs: strucExposureISOs)
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + monitorTimeDelay) {
            cameraServiceBrowser.sendPacket(packet)
            photoReceiver.dataReceivers.insertFirst(
                StatusUpdateReceiver( { (_ update: CameraStatusUpdate) in captureInvertedBinaryCode(statusUpdate: update)})
            )
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
        let packet = CameraInstructionPacket(cameraInstruction: CameraInstruction.FinishCapturePair, resolution: resolution, photoBracketExposureDurations: strucExposureDurations, binaryCodeBit: currentCodeBit, photoBracketExposureISOs: strucExposureISOs)
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + monitorTimeDelay) {
            cameraServiceBrowser.sendPacket(packet)
            
            
            if (shouldSendThreshImgs) {
                let direction = horizontal ? 1 : 0
                let prethreshpath = dirStruc.prethresh + "/proj\(projector)/pos\(position)"//dirStruc.subdir(dirStruc.prethresh)
                let threshpath = dirStruc.thresh + "/proj\(projector)/pos\(position)"
                for path in [prethreshpath, threshpath] { try! FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil) }
                let handler2 = captureNextBinaryCode
                let handler1 = {
                    photoReceiver.dataReceivers.insertFirst(
                        CalibrationImageReceiver(handler2, dir: threshpath, id: currentCodeBit-1)//"tmp/thresh/\(horizontal ? "h" : "v")", id: currentCodeBit-1)
                    )
                }
                photoReceiver.dataReceivers.insertFirst(
                    CalibrationImageReceiver(handler1, dir: prethreshpath, id: currentCodeBit-1) //"tmp/prethresh/\(horizontal ? "h" : "v")", id: currentCodeBit-1)
                )
            } else {
                photoReceiver.dataReceivers.insertFirst(
                    StatusUpdateReceiver { (update: CameraStatusUpdate) in
                        captureNextBinaryCode()
                    }
                )
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
    var received = false
    var completionHandler = { (path: String) in
        decodedImageHandler(path, horizontal: false, projector: projector, position: position)
        //received = true
    }
    imgpath = "\(dirStruc.decoded(proj: projector, pos: position, rectified: false))/result\(position)\(horizontal ? "v" : "u")-0initial.pfm"
    photoReceiver.dataReceivers.insertFirst(
        DecodedImageReceiver(completionHandler, path: imgpath, horizontal: false)
    )
    
    var metadataCompletionHandler: ()->Void = {
//        if rectificationMode == .NONE || rectificationMode == .ON_PHONE {
            let direction: Int = horizontal ? 1 : 0
        let filepath = dirStruc.metadataFile(horizontal ? 1 : 0, proj: projector, pos: position)
            do {
                let metadataStr = try String(contentsOfFile: filepath)
                let metadata: Yaml = try Yaml.load(metadataStr)
                var decodedImPath = *"\(dirStruc.decoded(proj: projector, pos: position, rectified: false))/result\(position)\(direction == 0 ? "u" : "v")-0initial.pfm" // dirStruc.decodedFile(direction, proj: projector, pos: position).cString(using: .ascii)!
                var outdir = *dirStruc.decoded(proj: projector, pos: position, rectified: false) //dirStruc.subdir(dirStruc.refined, proj: projector, pos: position).cString(using: .ascii)!
                if let angle: Double = metadata.dictionary?[Yaml.string("angle")]?.double {
                    var posID = *"\(position)"
                    refineDecodedIm(&outdir, Int32(direction), &decodedImPath, angle, &posID)
                } else {
                    print("refine error: could not load angle (double) from YML file.")
                }
            } catch {
                print("refine error: could not load metadata file.")
            }
//        } else {
//            print("skipping refine...")
//        }
        received = true
    }
    photoReceiver.dataReceivers.insertFirst(
        SceneMetadataReceiver(metadataCompletionHandler, path: dirStruc.metadataFile(horizontal ? 1 : 0, proj: projector, pos: position))
    )
    
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
    received = false
    completionHandler = { (path: String) in
        decodedImageHandler(path, horizontal: true, projector: projector, position: position)
//        received = true
    }
    imgpath = "\(dirStruc.decoded(proj: projector, pos: position, rectified: false))/result\(position)\(horizontal ? "v" : "u")-0initial.pfm"
    photoReceiver.dataReceivers.insertFirst(
        DecodedImageReceiver(completionHandler, path: imgpath, horizontal: true)
    )
    
    metadataCompletionHandler  = {
        let filepath = dirStruc.metadataFile(horizontal ? 1 : 0, proj: projector, pos: position)
        do {
            let metadataStr = try String(contentsOfFile: filepath)
            let metadata: Yaml = try Yaml.load(metadataStr)
            var decodedImPath = *"\(dirStruc.decoded(proj: projector, pos: position, rectified: false))/result\(position)\(horizontal ? "v" : "u")-0initial.pfm" //dirStruc.decodedFile(horizontal ? 1 : 0, proj: projector, pos: position).cString(using: .ascii)!
            var outdir = *dirStruc.decoded(proj: projector, pos: position, rectified: false) //dirStruc.subdir(dirStruc.refined, proj: projector, pos: position).cString(using: .ascii)!
            if let angle: Double = metadata.dictionary?[Yaml.string("angle")]?.double {
                var posID = *"\(position)"
                refineDecodedIm(&outdir, horizontal ? 1:0, &decodedImPath, angle, &posID)
            } else {
                print("refine error: could not load angle (double) from YML file.")
            }
        } catch {
            print("refine error: could not load metadata file.")
        }
        received = true
    }
    photoReceiver.dataReceivers.insertFirst(
        SceneMetadataReceiver(metadataCompletionHandler, path: dirStruc.metadataFile(horizontal ? 1 : 0, proj: projector, pos: position))
    )
    
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
    let leftSubdir = dirStruc.stereoPhotos(pos0)//dirStruc.stereoPhotosPairLeft(left: pos0, right: pos1)
    let rightSubdir = dirStruc.stereoPhotos(pos1)//dirStruc.stereoPhotosPairRight(left: pos0, right: pos1)
    
    // delete all existing photos
//    func removeImages(dir: String) -> Void {
//        guard let paths = try? FileManager.default.contentsOfDirectory(atPath: dir) else {
//            return
//        }
//        for path in paths {
//            do { try FileManager.default.removeItem(atPath: "\(dir)/\(path)") }
//            catch let error { print(error.localizedDescription) }
//        }
//    }
    removeFiles(dir: leftSubdir)
    removeFiles(dir: rightSubdir)
        
    
    
    let settingsPath = dirStruc.calibrationSettingsFile
    var cSettingsPath = settingsPath.cString(using: .ascii)!
    let settings = CalibrationSettings(settingsPath)
    settings.set(key: .Calibration_Pattern, value: Yaml.string("ARUCO_SINGLE"))
    settings.set(key: .Mode, value: Yaml.string("STEREO"))
    settings.save()

    
    var index: Int = 0
    while index < nPhotos {
        var posStr = positions[pos0].cString(using: .ascii)!
        MovePose(&posStr, robotAcceleration, robotVelocity)
        print(msgBoard)
        guard calibration_wait() else {
            return
        }
        
        // take photo at pos0
        cameraServiceBrowser.sendPacket(packet)
        receivedCalibrationImage = false
        photoReceiver.dataReceivers.insertFirst(
            CalibrationImageReceiver(completionHandler, dir: leftSubdir, id: index)
        )
        while !receivedCalibrationImage {}
        
        posStr = positions[pos1].cString(using: .ascii)!
        MovePose(&posStr, robotAcceleration, robotVelocity)
        print(msgMove)
        guard calibration_wait() else {
            return
        }
        
        // take photo at pos1
        cameraServiceBrowser.sendPacket(packet)
        receivedCalibrationImage = false
        
        photoReceiver.dataReceivers.insertFirst(
            CalibrationImageReceiver(completionHandler, dir: rightSubdir, id: index)
        )
        while !receivedCalibrationImage {}
        
        var leftpath = *"\(leftSubdir)/IMG\(index).JPG"
        var rightpath = *"\(rightSubdir)/IMG\(index).JPG"
        let shouldSkip: Bool
//        var cSettingsPath2 = cSettingsPath
//        var leftpath2 = *leftpath
//        var rightpath2 = *rightpath
        _ = DetectionCheck(&cSettingsPath, &leftpath, &rightpath)
        switch readLine() {
        case "c","k":
            shouldSkip = false
        case "s","r","i":
            shouldSkip = true
        default:
            shouldSkip = false
        }
        if shouldSkip {
            print("skipping...")
        } else {
            index += 1
        }
    }
}


// captureNPosCalibration: takes stereo calibration photos for all N positions
// not yet optimized
func captureNPosCalibration(posIDs: [Int], nPhotos: Int, resolution: String = "high", appending: Bool = false) {
    let packet = CameraInstructionPacket(cameraInstruction: .CaptureStillImage, resolution: resolution)
    var photoID: Int
    func receiveCalibrationImageSync(dir: String, id: Int) {
        var received = false
        let completionHandler = {
            received = true
        }
        cameraServiceBrowser.sendPacket(packet)
        let dataReceiver = CalibrationImageReceiver(completionHandler, dir: dir, id: id)
        photoReceiver.dataReceivers.insertFirst(dataReceiver)
        while !received {}
    }
    
    let msgMove = "Hit enter when camera in position."
    let msgBoard = "Hit enter when board repositioned."
    
    let stereoDirs = posIDs.map {
        return dirStruc.stereoPhotos($0)
    }
    let stereoDirDict = posIDs.reduce([Int : String]()) { (dict: [Int : String], id: Int) in
        var dictNew = dict
        dictNew[id] = dirStruc.stereoPhotos(id)
        return dictNew
    }
    
    if appending {
       // not yet implemented
        let idArray: [[Int]] = stereoDirs.map { (stereoDir: String) in
            let existingPhotos = try! FileManager.default.contentsOfDirectory(atPath: stereoDir)
            return getIDs(existingPhotos, prefix: "IMG", suffix: ".JPG")
        }
        let maxVal = idArray.map {
            return $0.max() ?? -1 // find max photo ID, or -1 if no photos empty, so that counting will begin at 0
        }.max() ?? -1
        // maxVal = max(idArray)
        photoID = maxVal + 1
    } else {
        // erase directories
        for dir in stereoDirs {
            removeFiles(dir: dir)
        }
        photoID = 0
    }
    
    let settingsPath = dirStruc.calibrationSettingsFile
    var cSettingsPath = settingsPath.cString(using: .ascii)!
    let settings = CalibrationSettings(settingsPath)
    settings.set(key: .Calibration_Pattern, value: Yaml.string("ARUCO_SINGLE"))
    settings.set(key: .Mode, value: Yaml.string("STEREO"))
    settings.save()
    
    // take the photos
    while photoID < nPhotos {
        print(msgBoard)
        var i = 0
        while i < posIDs.count {
            let posID = posIDs[i]
            var posStr = *positions[posID]
            MovePose(&posStr, robotAcceleration, robotVelocity)
            print(msgMove)
            guard calibration_wait() else {
                return
            }
            
            // take photo at pos0
            guard let photoDir = stereoDirDict[posID] else {
                print("stereocalib: ERROR -- could not find directory for position \(posID)")
                return
            }
            receiveCalibrationImageSync(dir: photoDir, id: photoID)
            
            if i > 0 {
                // now perform detection check
                var leftpath = *"\(stereoDirDict[posID]!)/IMG\(photoID).JPG"
                var rightpath = *"\(stereoDirDict[posID-1]!)/IMG\(photoID).JPG"
                _ = DetectionCheck(&cSettingsPath, &leftpath, &rightpath)
            }
            i += 1
        }
        print("continue (c) or skip (s)?")
        let shouldSkip: Bool
        switch readLine() {
        case "c","k":
            shouldSkip = false
        case "s","r","i":
            shouldSkip = true
        default:
            shouldSkip = false
        }
        if shouldSkip {
            print("skipping...")
        } else {
            photoID += 1
        }
            
    }
    
    
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
    guard NSScreen.screens.count > 1  else {
        print("Only one screen connected.")
        return false
    }
    for screen in NSScreen.screens {
        if screen != NSScreen.main! {
            displayController.createNewWindow(on: screen)
        }
    }
    return true
}



// CALIBRATION UTIL FUNCTIONS
func calibration_wait() -> Bool {
    var input: String
    repeat {
        guard let inputtmp = readLine() else {
            return false
        }
        input = inputtmp
        let tokens = input.split(separator: " ")
        if tokens.count == 0 {
            return true
        } else if ["exit", "e", "q", "quit", "stop", "end"].contains(tokens[0]) {
            return false
        } else if tokens.count == 2, let x = Float(tokens[0]), let y = Float(tokens[1]) {
            let point = CGPoint(x: CGFloat(x), y: CGFloat(y))
            let packet = CameraInstructionPacket(cameraInstruction: .SetPointOfFocus, pointOfFocus: point)
            cameraServiceBrowser.sendPacket(packet)
            _ = photoReceiver.receiveLensPositionSync()
        } else {
            return true
        }
    } while true
}
