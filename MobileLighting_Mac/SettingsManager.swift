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
class InitSettings {
    // required
    var scenesDirectory: String
    var sceneName: String
    var minSWfilepath: String
    
    // structured lighting
    var nProjectors: Int
    var exposureDurations: [Double]
    var exposureISOs: [Double]
    
    // robot arm movement
    var positionCoords: [String]
    
    // calibration
    var focus: Double?
    var calibrationExposureDurations: [Double]?
    var calibrationExposureISOs: [Double]?
    
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
            let minSWfilepath = mainDict[Yaml.string("minSWdataDir")]?.string else {
                throw YamlError.MissingRequiredKey
        }
        self.scenesDirectory = scenesDirectory
        self.sceneName = sceneName
        self.minSWfilepath = minSWfilepath
        
        self.nProjectors = (mainDict[Yaml.string("projectors")]?.int)!
        self.exposureDurations = (mainDict[Yaml.string("exposureDurations")]?.array?.filter({return $0.double != nil}).map{
            (val: Yaml) -> Double in
            return val.double!
            })!
        self.exposureISOs = (mainDict[Yaml.string("exposureISOs")]?.array?.filter({return $0.double != nil}).map{
            (val: Yaml) -> Double in
            return val.double!
            })!
        self.positionCoords = (mainDict[Yaml.string("positions")]?.array?.filter({return $0.string != nil}).map{
            (val: Yaml) -> String in
            return val.string!
            })!
        self.focus = mainDict[Yaml.string("focus")]?.double
        self.calibrationExposureDurations = mainDict[Yaml.string("calibrationExposureDurations")]?.array?.map {
            return $0.double!
        }
        self.calibrationExposureISOs = mainDict[Yaml.string("calibrationExposureISOs")]?.array?.map {
            return $0.double!
        }
        
        guard self.exposureDurations.count == self.exposureISOs.count else {
            fatalError("invalid initsettings file: mismatch in number of exposure durations & ISOs.")
        }
    }
}

// SceneParameters: will represent the parameters determined during and after scene capture,
//   including the locations of each camera position (in robot arm coordinates), etc
//   -contains two further groups of parameters: structured lighting parameters and calibration
//      parameters
//
// IMPORTANT: this has not yet been implemented -- eventually, it should be used when writing
//   scene parameters to YML file as well as reading scene parameters for use during image processing, e.g.
class SceneParameters {
    var sceneName: String!
    var nPositions: Int { get { return self.positions.count } }
    var positions: [String]!
    var structuredLighting: StructuredLightingParameters!
}

class StructuredLightingParameters {
    var nProjectors: Int!
    var resolution: String!
    var nExposures: Int { get { return self.exposureDurations.count } }
    var exposureDurations: [Double]!
    var exposureISOs: [Double]!
    var lensPosition: Float!
    var focusPoint: CGPoint?
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
}
