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
    var positionCoords: [Int]?
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
    var positions: [Int]!
    var structuredLighting: StructuredLightingParameters!
    var calibration: CalibrationParameters!
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

class CalibrationParameters {
    
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
    initSettings.positionCoords = mainDict[Yaml.string("positions")]?.array?.filter({return $0.int != nil}).map{
        (val: Yaml) -> Int in
        return val.int!
    }
    
    return initSettings
}
