import Foundation
import Yaml

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
