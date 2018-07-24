// Mobile Lighting control software
//
// DESCRIPTION:
// main script for the Mac control program
//
//  main.swift
//  demo_mac
//
//  Created by Nicholas Mosier on 6/2/17.
//  Last modified 7/14/17
//

import Foundation
import Cocoa
import CoreFoundation
import CocoaAsyncSocket
import AVFoundation
import SwitcherCtrl
import VXMCtrl
import Yaml

// creates shared application instance
//  required in order for windows (for displaying binary codes) to display properly,
//  since the Mac program compiles to a command-line binary
var app = NSApplication.shared

// Communication devices
var cameraServiceBrowser: CameraServiceBrowser!
var photoReceiver: PhotoReceiver!
var displayController: DisplayController!   // manages Kramer switcher box
var vxmController: VXMController!

var sceneSettings: SceneSettings!

// use minsw codes, not graycodes
let binaryCodeSystem: BinaryCodeSystem = .MinStripeWidthCode

// required settings vars
var scenesDirectory: String
var sceneName: String
var minSWfilepath: String

// optional settings vars
//var projectors: Int?
//var exposureDurations: [Double]
//var exposureISOs: [Double]
var positions: [String]
let focus: Double?

let mobileLightingUsage = "MobileLighting [path to sceneSettings.yml]\n       MobileLighting init [path to scenes folder [scene name]?]?"
// parse command line arguments
guard CommandLine.argc >= 2 else {
    print("usage: \(mobileLightingUsage)")
    exit(0)
}

switch CommandLine.arguments[1] {
case "init":
    // initialize settings files, then quit
    print("MobileLighting: entering init mode...")
    if CommandLine.argc == 2 {
        print("location of scenes folder: ", terminator: "")
        scenesDirectory = readLine() ?? ""
    } else {
        scenesDirectory = CommandLine.arguments[2]
    }
    if CommandLine.argc == 4 {
        sceneName = CommandLine.arguments[3]
    } else {
        print("scene name: ", terminator: "")
        sceneName = readLine() ?? "untitled"
    }
    
    do {
        dirStruc = DirectoryStructure(scenesDir: scenesDirectory, currentScene: sceneName)
        try SceneSettings.create(dirStruc)
        print("successfully created settings file at \(scenesDirectory)/\(sceneName)/settings/sceneSettings.yml")
    } catch let error {
        print(error.localizedDescription)
    }
    print("MobileLighting exiting...")
    exit(0)
    
case let path where path.lowercased().hasSuffix(".yml"):
    do {
        sceneSettings = try SceneSettings(path)
    } catch let error {
        print(error.localizedDescription)
        print("MobileLighting exiting...")
        exit(0)
    }
    
default:
    print("usage: \(mobileLightingUsage)")
    exit(0)
}


// load init settings
//do {
//    sceneSettings = try SceneSettings(sceneSettingsPath)
//    print("Successfully loaded initial settings.")
//} catch {
//    print("Fatal error: could not load init settings")
//    exit(0)
//}

// save required settings
scenesDirectory = sceneSettings.scenesDirectory
sceneName = sceneSettings.sceneName
minSWfilepath = sceneSettings.minSWfilepath


positions = sceneSettings.trajectory.waypoints

var strucExposureDurations = sceneSettings.strucExposureDurations
var strucExposureISOs = sceneSettings.strucExposureISOs
var calibrationExposure = (sceneSettings.calibrationExposureDuration ?? 0, sceneSettings.calibrationExposureISO ?? 0)

var trajectory = sceneSettings.trajectory

// calibration settings
focus = sceneSettings.focus

// setup directory structure
dirStruc = DirectoryStructure(scenesDir: scenesDirectory, currentScene: sceneName)
do {
    try dirStruc.createDirs()
} catch {
    print("Could not create directory structure at \(dirStruc.scenes)")
    exit(0)
}


initializeIPhoneCommunications()

// focus iPhone if focus provided
if focus != nil {
    let packet = CameraInstructionPacket(cameraInstruction: CameraInstruction.SetLensPosition, lensPosition: Float(focus!))
    cameraServiceBrowser.sendPacket(packet)
    let receiver = LensPositionReceiver { _ in return }
    photoReceiver.dataReceivers.insertFirst(receiver)
}

if configureDisplays() {
    print("main: Successfully configured displays.")
} else {
    print("main: ERROR — failed to configure displays.")
}



let mainQueue = DispatchQueue(label: "mainQueue")
//let mainQueue = DispatchQueue.main    // for some reason this causes the NSSharedApp (which manages the windwos for displaying binary codes, etc) to block! But the camera calibration functions must be run from the DisplatchQueue.main, so async them whenever they are called

mainQueue.async {
    
    while nextCommand() {}
    
    NSApp.terminate(nil)    // terminates shared application
}

NSApp.run()

