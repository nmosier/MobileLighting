//
//  SettingsManager.swift
//  demo
//
//  Created by Nicholas Mosier on 7/5/17.
//  Copyright © 2017 Nicholas Mosier. All rights reserved.
//

import Foundation
import Yaml

// simple error enum for when trying to read YML settings files
enum YamlError: Error {
    case InvalidFormat
    case MissingRequiredKey
}

//MARK: SETTINGS CLASSES

// InitSettings: represents all settings required for capturing a new scene
// read from YML file
// -consists of required and optional settings
class SceneSettings {
    var scenesDirectory: String
    var sceneName: String
    var minSWfilepath: String
    var trajectoryPath: String
    
    // other settings
    var trajectory: Trajectory
    
    // structured lighting
    var strucExposureDurations: [Double]
    var strucExposureISOs: [Double]
    
    // robot arm movement
//    var positionCoords: [String]
    
    // calibration
    var focus: Double?
    var calibrationExposureDuration: Double?
    var calibrationExposureISO: Double?
    
    // ambient
    var ambientExposureDurations: [Double]?
    var ambientExposureISOs: [Double]?
    
    static var format: Yaml {
        get {
            var maindict = [Yaml : Yaml]()
            maindict[Yaml.string("scenesDir")] = Yaml.string("")
            maindict[Yaml.string("sceneName")] = Yaml.string("")
            maindict[Yaml.string("minSWdataPath")] = Yaml.string("")
            maindict[Yaml.string("trajectoryPath")] = Yaml.string("")
            var struclight = [Yaml : Yaml]()
            struclight[Yaml.string("exposureDurations")] = Yaml.array([0.01,0.03,0.10].map{return Yaml.double($0)})
            struclight[Yaml.string("exposureISOs")] = Yaml.array([50.0,150.0,500.0].map{ return Yaml.double($0)})
            maindict[Yaml.string("struclight")] = Yaml.dictionary(struclight)
            maindict[Yaml.string("focus")] = Yaml.double(0.0)
            var calibration = [Yaml : Yaml]()
            calibration[Yaml.string("exposureDuration")] = Yaml.double(0.055)
            calibration[Yaml.string("exposureISO")] = Yaml.double(66.5)
            maindict[Yaml.string("calibration")] = Yaml.dictionary(calibration)
            var ambient = [Yaml : Yaml]()
            ambient[Yaml.string("exposureDurations")] = Yaml.array([0.035,0.045,0.055].map{return Yaml.double($0)})
            ambient[Yaml.string("exposureISOs")] = Yaml.array([50.0,60.0,70.0].map{ return Yaml.double($0)})
            maindict[Yaml.string("ambient")] = Yaml.dictionary(ambient)
            return Yaml.dictionary(maindict)
        }
    }
    
    init(_ filepath: String) throws {
        let settingsStr = try String(contentsOfFile: filepath)
        let settings: Yaml = try Yaml.load(settingsStr)
        
        // init settings file should be dictionary at top level
        guard let mainDict = settings.dictionary else {
            throw YamlError.InvalidFormat
        }
        
        // process required properties:
        guard let scenesDirectory = mainDict[Yaml.string("scenesDir")]?.string,
            let sceneName = mainDict[Yaml.string("sceneName")]?.string,
            let minSWfilepath = mainDict[Yaml.string("minSWdataPath")]?.string else {
                throw YamlError.MissingRequiredKey
        }
        self.scenesDirectory = scenesDirectory
        self.sceneName = sceneName
        self.minSWfilepath = minSWfilepath
        
        self.strucExposureDurations = (mainDict[Yaml.string("struclight")]?.dictionary?[Yaml.string("exposureDurations")]?.array?.filter({return $0.double != nil}).map{
            (val: Yaml) -> Double in
            return val.double!
            })!
        self.strucExposureISOs = (mainDict[Yaml.string("struclight")]?.dictionary?[Yaml.string("exposureISOs")]?.array?.filter({return $0.double != nil}).map{
            (val: Yaml) -> Double in
            return val.double!
            })!
//        self.positionCoords = (mainDict[Yaml.string("positions")]?.array?.filter({return $0.string != nil}).map{
//            (val: Yaml) -> String in
//            return val.string!
//            })!
        self.focus = mainDict[Yaml.string("focus")]?.double
        
        if let calibrationDict = mainDict[Yaml.string("calibration")]?.dictionary {
            if let iso = calibrationDict[Yaml.string("exposureISO")]?.double {
                self.calibrationExposureISO = iso
            }
            if let duration = calibrationDict[Yaml.string("exposureDuration")]?.double {
                self.calibrationExposureDuration = duration
            }
        }
        
        if let ambientDict = mainDict[Yaml.string("ambient")] {
            self.ambientExposureISOs = ambientDict[Yaml.string("exposureISOs")].array?.compactMap {
                return $0.double
            }
            self.ambientExposureDurations = ambientDict[Yaml.string("exposureDurations")].array?.compactMap {
                return $0.double
            }
        }
        
        guard let trajectoryPath = mainDict[Yaml.string("trajectoryPath")]?.string else {
            print("path to trajectory.yml missing from scene settings file.")
            fatalError()
        }
        self.trajectoryPath = trajectoryPath
        
        guard self.strucExposureDurations.count == self.strucExposureISOs.count else {
            fatalError("invalid initsettings file: mismatch in number of exposure durations & ISOs.")
        }
        
        self.trajectory = Trajectory(trajectoryPath)
    }
    
    static func create(_ dirStruc: DirectoryStructure) throws {
        let path = "\(dirStruc.settings)/sceneSettings.yml"
        let dir = ((path.first == "/") ? "/" : "") + path.split(separator: "/").dropLast().joined(separator: "/")
        //print("path: \(dir)")
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
        let yml = try SceneSettings.format.save()
        try yml.write(toFile: path, atomically: true, encoding: .ascii)
        
        try Trajectory.create(dirStruc)
    }
    
}


func generateIntrinsicsImageList(imgsdir: String = dirStruc.intrinsicsPhotos, outpath: String = dirStruc.intrinsicsImageList) {
    guard var imgs = try? FileManager.default.contentsOfDirectory(atPath: imgsdir) else {
        print("could not read contents of directory \(imgsdir)")
        return
    }
    
    imgs = imgs.filter { (_ filepath: String) in
        guard let file = filepath.split(separator: "/").last else { return false }
        guard file.hasPrefix("IMG"), file.hasSuffix(".JPG"), Int(file.dropFirst("IMG".count).dropLast(".JPG".count)) != nil else {
            return false
        }
        return true
    }
    //var yml: Yaml = Yaml(dictionaryLiteral: "images")
    var imgList: [Yaml] = [Yaml]()
    for path in imgs {
        imgList.append(Yaml.string("\(imgsdir)/\(path)"))
    }
    let ymlList = Yaml.array(imgList)
    let ymlDict = Yaml.dictionary([Yaml.string("images") : ymlList])
//    let ymlStr = try! ymlDict.save()
//    print(outpath)
    try! Yaml.save(ymlDict, toFile: outpath)
//    try! ymlStr.write(to: URL(fileURLWithPath: outpath), atomically: true, encoding: .utf8)
}

func generateStereoImageList(left ldir: String, right rdir: String, outpath: String = dirStruc.stereoImageList) {
    guard var limgs = try? FileManager.default.contentsOfDirectory(atPath: ldir), var rimgs = try? FileManager.default.contentsOfDirectory(atPath: rdir) else {
        print("could not read contents of directory \(ldir) or \(rdir)")
        return
    }
    
    let filterIms: (String) -> Bool = { (_ filepath: String) in
        let file = filepath.split(separator: "/").last!
        return (file.hasPrefix("IMG") || file.hasPrefix("img")) && (file.hasSuffix(".JPG") || file.hasSuffix(".jpg"))
    }
    limgs = limgs.filter(filterIms)
    rimgs = rimgs.filter(filterIms)
    let mapNames: (String) -> String = {(_ fullpath: String) in
        return String(fullpath.split(separator: "/").last!)
    }
    let lnames = limgs.map(mapNames)
    let rnames = rimgs.map(mapNames)
    let names = Set(lnames).intersection(rnames)
    var imgList = [Yaml]()
    for name in names {
        imgList.append(Yaml(stringLiteral: "\(ldir)/\(name)"))
        imgList.append(Yaml(stringLiteral: "\(rdir)/\(name)"))
    }
    let ymlList = Yaml.array(imgList)
    let ymlDict = Yaml(dictionaryLiteral: (Yaml(stringLiteral: "images"), ymlList))
    try! Yaml.save(ymlDict, toFile: outpath)
//    try! ymlDict.save().write(to: URL(fileURLWithPath: outpath), atomically: true, encoding: .utf8)
}

class CalibrationSettings {
    let filepath: String
    var yml: Yaml
    
    enum CalibrationMode: String {
        case INTRINSIC, STEREO, PREVIEW
    }
    enum CalibrationPattern: String {
        case CHESSBOARD, ARUCO_SINGLE
    }
    
    enum Key: String {
        case Mode, Calibration_Pattern, ChessboardSize_Width
        case ChessboardSize_Height
        case Num_MarkersX, Num_MarkersY
        case First_Marker
        case Num_of_Boards
        case ImageList_Filename
        case IntrinsicInput_Filename, IntrinsicOutput_Filename, ExtrinsicOutput_Filename
        case UndistortedImages_Path, RectifiedImages_Path
        case DetectedImages_Path, Calibrate_FixDistCoeffs
        case Calibrate_FixAspectRatio, Calibrate_AssumeZeroTangentialDistortion
        case Calibrate_FixPrincipalPointAtTheCenter
        case Show_UndistortedImages, ShowRectifiedImages
        case Wait_NextDetecedImage
    }
    
    init(_ path: String) {
        self.filepath = path
        do {
            let ymlStr = try String(contentsOfFile: self.filepath)
            let tmp = try Yaml.load(ymlStr)
            guard let dict = tmp.dictionary else {
                throw YamlError.InvalidFormat
            }
            guard dict[Yaml.string("Settings")] != nil else {
                throw YamlError.MissingRequiredKey
            }
            self.yml = dict[Yaml.string("Settings")]!
        } catch let error {
            print(error.localizedDescription)
            fatalError()
        }
    }
    
    func set(key: Key, value: Yaml) {
        guard var dict = self.yml.dictionary else { return }
        dict[Yaml.string(key.rawValue)] = value
        self.yml = Yaml.dictionary(dict)
    }
    
    func get(key: Key) -> Yaml? {
        guard var dict = self.yml.dictionary else { return nil }
        return dict[Yaml.string(key.rawValue)]
    }
    
    func save() {
        try! Yaml.save(Yaml.dictionary([Yaml.string("Settings") : self.yml]), toFile: filepath)
//        let out = try! Yaml.dictionary([Yaml.string("Settings") : self.yml]).save()
//        try! out.write(to: URL(fileURLWithPath: filepath), atomically: true, encoding: .utf8)
    }
    
    static var format: Yaml {
        get {
            var settingsDict = [Yaml : Yaml]()
            settingsDict["Num_MarkersX"] = Yaml.array([8,8].map{return Yaml.int($0)})
            settingsDict["Num_MarkersY"] = Yaml.array([8,7].map{return Yaml.int($0)})
            settingsDict["Num_of_Boards"] = Yaml.int(2)
            settingsDict["ChessboardSize_Width"] = Yaml.int(17)
            settingsDict["ChessboardSize_Height"] = Yaml.int(12)
            settingsDict["Calibration_Pattern"] = Yaml.string("(automatically configured)")
            settingsDict["Calibrate_AssumeZeroTangentialDistortion"] = Yaml.int(1)
            settingsDict["ImageList_Filename"] = Yaml.string("(automatically configured)")
            settingsDict["ExtrinsicOutput_Filename"] = Yaml.string("(automatically configured)")
            settingsDict["Show_UndistortedImages"] = Yaml.int(0)
            settingsDict["Wait_NextDetectedImage"] = Yaml.int(0)
            settingsDict["IntrinsicInput_Filename"] = Yaml.string("(automatically configured)")
            settingsDict["Calibrate_FixPrincipalPointAtTheCenter"] = Yaml.int(0)
            settingsDict["UndistortedImages_Path"] = Yaml.string("0")
            settingsDict["DetectedImages_Path"] = Yaml.string("0")
            settingsDict["Show_RectifiedImages"] = Yaml.int(1)
            settingsDict["Square size"] = Yaml.double(25.4)
            settingsDict["IntrinsicOutput_Filename"] = Yaml.string("(automatically configured)")
            settingsDict["Dictionary"] = Yaml.int(11)
            settingsDict["Calibrate_FixAspectRatio"] = Yaml.int(0)
            settingsDict["RectifiedImages_Path"] = Yaml.string("0")
            settingsDict["Marker_Length"] = Yaml.array([72,108].map{return Yaml.double($0)})
            settingsDict["Calibrate_FixDistCoeffs"] = Yaml.string("00111")
            settingsDict["First_Marker"] = Yaml.array([113,516].map{return Yaml.int($0)})
            settingsDict["Mode"] = Yaml.string(CalibrationMode.STEREO.rawValue)
            settingsDict["Alpha parameters"] = Yaml.int(-1)
            settingsDict["Resizing factor"] = Yaml.int(2)
            let mainDict = Yaml.dictionary(settingsDict)
            return Yaml.dictionary([Yaml.string("Settings") : mainDict])
        }
    }
    
    static func create(_ dirStruc: DirectoryStructure) throws {
        let path = dirStruc.calibrationSettingsFile
        try Yaml.save(CalibrationSettings.format, toFile: path)
    }
}
