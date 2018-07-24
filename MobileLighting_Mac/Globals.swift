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
    } else if CommandLine.argc == 2 && CommandLine.arguments[1].hasSuffix(".yml") {
        return CommandLine.arguments[1]
    } else {
        print("usage: MobileLighting [path to scene settings file]?")
        var answer: String?
        while answer?.lowercased() != "y" && answer?.lowercased() != "n" {
            print("would you like to create a new scene settings file? (Y/n)")
            answer = readLine()
        }
        if answer?.lowercased() == "y" {
            // create new settings file
            print("name of scene: ", terminator: "")
            let currentScene = readLine() ?? "untitled"
            print("location of scenes folder: ", terminator: "")
            scenesDirectory = readLine() ?? ""
            do { try SceneSettings.create(DirectoryStructure(scenesDir: scenesDirectory, currentScene: currentScene)) }
            catch let error { print(error.localizedDescription) }
        }
        exit(0)
    }
}()

var dirStruc: DirectoryStructure!

