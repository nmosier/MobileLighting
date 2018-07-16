//
//  Globals.swift
//  MobileLighting_Mac
//
//  Created by Nicholas Mosier on 6/6/18.
//  Copyright © 2018 Nicholas Mosier. All rights reserved.
// contains global variables for Mac app

import Foundation

var currentPos: Int = -1
var currentProj: Int = -1

let sceneSettingsPath: String = { () -> String in
    if CommandLine.argc == 1 {
        return "/Users/nicholas/OneDrive - Middlebury College/Summer Research 2017/MobileLighting/initSettings.yml"
    } else if CommandLine.argc == 2 {
        return CommandLine.arguments[1]
    } else {
        print("usage: MobileLighting [path to scene settings file]?")
        exit(0)
    }
}()

//let sceneSettingsPath: String = "/Users/nicholas/OneDrive - Middlebury College/Summer Research 2017/MobileLighting/initSettings.yml"
var sceneSettings: SceneSettings!

var dirStruc: DirectoryStructure!

