import Foundation
import Yaml


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
    let leftSubdir = dirStruc.stereoPhotos(pos0)
    let rightSubdir = dirStruc.stereoPhotos(pos1)
    
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
        guard calibration_wait(currentPos: pos0) else {
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
        guard calibration_wait(currentPos: pos1) else {
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
            guard calibration_wait(currentPos: posID) else {
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
