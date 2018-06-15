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
    var scenesDirectory: String!
    var sceneName: String!
    var minSWfilepath: String!
    
    // optional
    var nProjectors: Int?
    var exposureDurations: [Double]?
    var exposureISOs: [Double]?
    var positionCoords: [String]?
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


// MARK: SETTINGS FUNCTIONS

// loadInitSettings: loads init settings from YML file at given filepath & returns InitSettings object
// 
// FORMAT of init settings file:
//  -is a DICTIONARY at top level; where all parameter settings keys are specified
//     -required keys:
//          'scenesDir' (must be absolute path)
//          'sceneName'
//          'minSWdataDir' (must be absolute path)
//     -optional keys:
//          'positions' - value is list of positions as ints (NOTE: currently not utilized)
//          'exposures' - value is list of exposure times as floats (IMPORTANT: this IS currently used)
//          'projectors' (int)
func loadInitSettings(filepath: String) throws -> InitSettings {
    let settingsStr = try String(contentsOfFile: filepath)
    let settings: Yaml = try Yaml.load(settingsStr)
    
    
    // init settings file should be dictionary at top level
    guard let mainDict = settings.dictionary else {
        throw YamlError.InvalidFormat
    }

    let initSettings = InitSettings()
    
    // process required properties:
    guard let scenesDirectory = mainDict[Yaml.string("scenesDir")]?.string,
        let sceneName = mainDict[Yaml.string("sceneName")]?.string,
        let minSWfilepath = mainDict[Yaml.string("minSWdataDir")]?.string else {
            throw YamlError.MissingRequiredKey
    }
    initSettings.scenesDirectory = scenesDirectory
    initSettings.sceneName = sceneName
    initSettings.minSWfilepath = minSWfilepath
    
    // read in optional properties
    initSettings.nProjectors = mainDict[Yaml.string("projectors")]?.int
    initSettings.exposureDurations = mainDict[Yaml.string("exposureDurations")]?.array?.filter({return $0.double != nil}).map{
        (val: Yaml) -> Double in
        return val.double!
    }
    initSettings.exposureISOs = mainDict[Yaml.string("exposureISOs")]?.array?.filter({return $0.double != nil}).map{
        (val: Yaml) -> Double in
        return val.double!
    }
    initSettings.positionCoords = mainDict[Yaml.string("positions")]?.array?.filter({return $0.string != nil}).map{
        (val: Yaml) -> String in
        return val.string!
    }
    
    return initSettings
}


func generateIntrinsicsImageList(imgsdir: String = dirStruc.intrinsicsPhotos, outpath: String = dirStruc.calibrationSettings + "/intrinsicsImageList.yml") {
    guard var imgs = try? FileManager.default.contentsOfDirectory(atPath: imgsdir) else {
        print("could not read contents of directory \(imgsdir)")
        return
    }
    imgs = imgs.filter { (_ filepath: String) in
        let file = filepath.split(separator: "/").last!
        return (file.hasPrefix("IMG") || file.hasPrefix("img")) && (file.hasSuffix(".JPG") || file.hasSuffix(".jpg"))
    }
    //var yml: Yaml = Yaml(dictionaryLiteral: "images")
    var imgList: [Yaml] = [Yaml]()
    for path in imgs {
        imgList.append(Yaml.string(path))
    }
    let ymlList = Yaml.array(imgList)
    let ymlDict = Yaml.dictionary([Yaml.string("images") : ymlList])
    let ymlStr = try! ymlDict.save()
    print(outpath)
    try! ymlStr.write(to: URL(fileURLWithPath: outpath), atomically: true, encoding: .utf8)
}

func generateStereoImageList(left ldir: String, right rdir: String, outpath: String = dirStruc.calibrationSettings + "/stereoImageList.yml") {
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
    try! ymlDict.save().write(to: URL(fileURLWithPath: outpath), atomically: true, encoding: .utf8)
}


class CalibrationSettings {
    let filepath: String
    var yml: Yaml
    
    enum CalibrationMode: String {
        case INTRINSIC, STEREO, PREVIEW
    }
    enum CalibrationPattern: String {
        case CHESSBOARD, ARUCO_SINGLE, ARUCO_BOX
    }
    
    enum Key: String {
        case Mode, Calibration_Pattern, ChessboardSize_Width
        case ChessboardSize_Height, ImageList_Filename
        case ArucoConfig_Filename, IntrinsicInput_Filename
        case IntrinsicOutput_Filename, ExtrinsicOutput_Filename
        case UndistortedImages_Path, RectifiedImages_Path
        case DetectedImages_Path, Calibrate_FixDistCoeffs
        case Calibrate_FixAspectRatio, Calibrate_AssumeZeroTangentialDistortion
        case Calibrate_FixPrincipalPointAtTheCenter
        case Show_UndistortedImages, ShowRectifiedImages, Show_ArucoMarkerCoordinates
        case Wait_NextDetecedImage, LivePreviewCameraID
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
        let out = try! Yaml.dictionary([Yaml.string("Settings") : self.yml]).save()
        try! out.write(to: URL(fileURLWithPath: filepath), atomically: true, encoding: .utf8)
    }
}
