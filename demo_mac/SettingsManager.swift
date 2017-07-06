//
//  SettingsManager.swift
//  demo
//
//  Created by Nicholas Mosier on 7/5/17.
//  Copyright © 2017 Nicholas Mosier. All rights reserved.
//

import Foundation
import Yaml

enum YamlError: Error {
    case InvalidFormat
    case MissingRequiredKey
}

/*
private func readpair(dict: key: String, type: AnyClass, to dest: inout Any) {
    
}*/

class InitSettings {
    // required
    var scenesDirectory: String!
    var sceneName: String!
    var minSWfilepath: String!
    
    // optional
    var nProjectors: Int?
    var exposures: [Double]?
    var positionCoords: [Int]?
}

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
    initSettings.exposures = mainDict[Yaml.string("exposures")]?.array?.filter({return $0.double != nil}).map{
        (val: Yaml) -> Double in
        return val.double!
    }
    initSettings.positionCoords = mainDict[Yaml.string("positions")]?.array?.filter({return $0.int != nil}).map{
        (val: Yaml) -> Int in
        return val.int!
    }
    
    return initSettings
}
