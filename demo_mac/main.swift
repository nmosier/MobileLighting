//
//  main.swift
//  demo_mac
//
//  Created by Nicholas Mosier on 6/2/17.
//  Copyright © 2017 Nicholas Mosier. All rights reserved.
//

import Foundation
import Cocoa
import CoreFoundation
import CocoaAsyncSocket
import AVFoundation

import SwitcherCtrl
import VXMCtrl


var app = NSApplication.shared()


test_wrapped()

//MARK: global configuration variables
var cameraServiceBrowser: CameraServiceBrowser!
var photoReceiver: PhotoReceiver!
var displayController: DisplayController!   // includes switcher
var vxmController: VXMController!

var scenesDirectory: String
var sceneName: String
var origSubdir: String, ambSubdir: String, ambBallSubdir: String, graycodeSubdir: String
var calibSubdir: String     // used in both orig and computed dirs
var computedSubdir: String, decodedSubdir: String, refinedSubdir: String

var minSWfilepath: String

var exposures: [Double]
var lensPosition: Float
var binaryCodeSystem: BinaryCodeSystem


// define directory structure
scenesDirectory = "/Users/nicholas/Desktop/scenes"
    sceneName = "scene"
    origSubdir = "orig"
        ambSubdir = "ambient"
        ambBallSubdir = "ambientBall"
        graycodeSubdir = "graycode"
        calibSubdir = "calibration"
    computedSubdir = "computed"
        decodedSubdir = "decoded"
        refinedSubdir = "refined"
minSWfilepath = "/Users/nicholas/OneDrive - Middlebury College/Summer Research 2017/MobileLighting/demo-mobile-scene-capture/minSW.dat"

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
    ] as Any?,
    computedSubdir  : [
        calibSubdir : nil,
        decodedSubdir   : [
            "left"  : nil,
            "right" : nil
        ] as [String : Any?],
        refinedSubdir   : [
            "left"  : nil,
            "right" : nil
        ]
    ] as Any?
]
createStaticDirectoryStructure(atPath: scenesDirectory+"/"+sceneName, structure: staticDirectoryStructure)

binaryCodeSystem = .MinStripeWidthCode
exposures = [0.01, 0.02, 0.05, 0.1]

 initializeIPhoneCommunications()

if configureDisplays() {
    print("main: Successfully configured displays.")
} else {
    print("main: ERROR — failed to configure displays.")
}

let mainQueue = DispatchQueue(label: "mainQueue")
mainQueue.async {
    //displayController.windows.first!.configureDisplaySettings(horizontal: false, inverted: false)
    //displayController.windows.first!.displayBinaryCode(forBit: 0, system: .MinStripeWidthCode)
    
    //while nextCommand() {}
    
    waitForEstablishedCommunications()
    
    // lock white balance before capture
    let packet = CameraInstructionPacket(cameraInstruction: .LockWhiteBalance)
    cameraServiceBrowser.sendPacket(packet)
    
    var receivedUpdate = false
    photoReceiver.receiveStatusUpdate(completionHandler: {(update: CameraStatusUpdate) in receivedUpdate = true})
    while !receivedUpdate {}
    
    while nextCommand() {}
}

let appDelegate = AppDelegate()
NSApp.delegate = appDelegate
NSApp.run()

