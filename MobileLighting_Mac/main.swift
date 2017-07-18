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

// creates shared application instance
//  required in order for windows (for displaying binary codes) to display properly,
//  since the Mac program compiles to a command-line binary
var app = NSApplication.shared()

// Communication devices
var cameraServiceBrowser: CameraServiceBrowser!
var photoReceiver: PhotoReceiver!
var displayController: DisplayController!   // manages Kramer switcher box
var vxmController: VXMController!

// Subdirectories in directory structure
var origSubdir: String, ambSubdir: String, ambBallSubdir: String, graycodeSubdir: String
var calibSubdir: String     // used in both orig and computed dirs
var computedSubdir: String, decodedSubdir: String, refinedSubdir: String, disparitySubdir: String
    origSubdir = "orig"
        ambSubdir = "ambient"
        ambBallSubdir = "ambientBall"
        graycodeSubdir = "graycode"
        calibSubdir = "calibration"
    computedSubdir = "computed"
        decodedSubdir = "decoded"
        refinedSubdir = "refined"
        disparitySubdir = "disparity"

// use minsw codes, not graycodes
let binaryCodeSystem: BinaryCodeSystem = .MinStripeWidthCode

// READ INITIAL SETTINGS

// required settings vars
var scenesDirectory: String
var sceneName: String
var minSWfilepath: String

// optional settings vars
var projectors: Int?
var exposures: [Double]
var positions: [Int]

let initSettingsPath: String = "/Users/nicholas/OneDrive - Middlebury College/Summer Research 2017/MobileLighting/initSettings.yml"
let initSettings: InitSettings
do {
    initSettings = try loadInitSettings(filepath: initSettingsPath)
    print("Successfully loaded initial settings.")
} catch {
    print("Fatal error: could not load init settings")
    exit(0)
}

// save required settings
scenesDirectory = initSettings.scenesDirectory
sceneName = initSettings.sceneName
minSWfilepath = initSettings.minSWfilepath

// setup optional settings
projectors = initSettings.nProjectors
exposures = initSettings.exposures ?? [Double]()
positions = initSettings.positionCoords ?? [Int]()

print("Exposures: \(exposures)")
print("Positions: \(positions)")
print("Projectors: \(projectors ?? 0)")

// create scene's directory structure
let staticDirectoryStructure: [String : Any?]
staticDirectoryStructure = [
    origSubdir      : [
        ambSubdir       : nil,
        ambBallSubdir   : nil,
        calibSubdir     : [
            "left"  : nil,
            "right" : nil
        ] as [String : Any?],
        graycodeSubdir  : nil
    ],
    computedSubdir  : [
        calibSubdir : nil,
        decodedSubdir   : nil,
        refinedSubdir   : nil,
        disparitySubdir : nil
    ] as [String : Any?]
]
createStaticDirectoryStructure(atPath: scenesDirectory+"/"+sceneName, structure: staticDirectoryStructure)

// publish PhotoReceiver service & set up Camera Service Browser
initializeIPhoneCommunications()

if configureDisplays() {
    print("main: Successfully configured displays.")
} else {
    print("main: ERROR — failed to configure displays.")
}

let mainQueue = DispatchQueue(label: "mainQueue")
mainQueue.async {
    //waitForEstablishedCommunications()
    
    /*
    var receivedUpdate = false
    photoReceiver.receiveStatusUpdate(completionHandler: {(update: CameraStatusUpdate) in receivedUpdate = true})
    while !receivedUpdate {}
    */
    
    while nextCommand() {}
}

NSApp.run()

