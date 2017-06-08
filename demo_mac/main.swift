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

let app = NSApplication.shared()

var cameraServiceBrowser: CameraServiceBrowser!
var photoReceiver: PhotoReceiver!
var displayController: DisplayController!
var sceneName: String
var exposures: [Double]




//MARK: Utility functions

func initializeIPhoneCommunications() {
    cameraServiceBrowser = CameraServiceBrowser()
    photoReceiver = PhotoReceiver()
    
    photoReceiver.startBroadcast()
    cameraServiceBrowser.startBrowsing()
}

func configureDisplays() -> Bool {
    displayController = DisplayController()
    guard NSScreen.screens()!.count > 1  else {
        print("Only one screen connected.")
        return false
    }
    
    for screen in NSScreen.screens()! {
        if screen != NSScreen.main()! {
            displayController.createNewWindow(on: screen)
        }
    }
    
    displayController.setCurrentScreen(withID: 0)   // set main secondary screen to be first in array
    return true
}



//MARK: execution body

sceneName = "scene"
exposures = [0.01]

initializeIPhoneCommunications()

if configureDisplays() {
    print("main: Successfully configured displays.")
} else {
    print("main: ERROR — failed to configure displays.")
}

let mainQueue = DispatchQueue(label: "mainQueue")
mainQueue.async {
    
    displayController.windows.first!.configureDisplaySettings(horizontal: false, inverted: false)
    displayController.windows.first!.displayBinaryCode(forBit: 9, system: .MinStripeWidthCode)
    
    while !cameraServiceBrowser.readyToSendPacket {}
    while !photoReceiver.readyToReceive {}
    
    
    let response = setLensPosition(0.5)
    print("Lens position set: \(response)")
    
    captureScene(using: BinaryCodeSystem.GrayCode)
    
}


NSApp.run()


