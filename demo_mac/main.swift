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

let app = NSApplication.shared()    // creates new shared application -- is necessary to create new windows
// will need to call NSApp.run() -> starts main event loop

var cameraServiceBrowser: CameraServiceBrowser!
var photoReceiver: PhotoReceiver!
var displayController: DisplayController!

let bracketCount = 10
var bracketNumber = 0

func createCGImage(filePath: String) -> CGImage {
    let url = NSURL(fileURLWithPath: filePath)
    let dataProvider = CGDataProvider(url: url)
    return CGImage(jpegDataProviderSource: dataProvider!, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
}

func captureNextBracket() {
    guard cameraServiceBrowser.readyToSendPacket else {
        return
    }
    
    if bracketNumber >= bracketCount {
        return
    }
    
    let image = createCGImage(filePath: "/Users/nicholas/Desktop/display_images/\(bracketNumber%2).jpg")
    displayController.windows.first!.image = image
    displayController.windows.first!.drawImage(image)
    
    let cameraInstruction = CameraInstruction.CapturePhotoBracket
    let cameraInstructionPacket = CameraInstructionPacket(cameraInstruction: cameraInstruction, captureSessionPreset: AVCaptureSessionPresetMedium)
    cameraServiceBrowser.sendPacket(cameraInstructionPacket)
    
    photoReceiver.receivePhotoBracket(name: "bracket\(bracketNumber)", photoCount: 3, completionHandler: captureNextBracket)
    bracketNumber += 1
}



func temp() {
    displayController = DisplayController()
    guard NSScreen.screens()!.count > 1  else {
        print("Only one screen connected.")
        return
    }
    for screen in NSScreen.screens()! {
        if screen != NSScreen.main()! {
            displayController.createNewWindow(on: screen)
        }
    }
    
    //displayController.windows.first!.image = createCGImage(filePath: "/Users/nicholas/Desktop/display_images/1.jpg")
    
    cameraServiceBrowser = CameraServiceBrowser()
    photoReceiver = PhotoReceiver()
    
    photoReceiver.startBroadcast()
    cameraServiceBrowser.startBrowsing()
    
    let instructionInputQueue = DispatchQueue(label: "com.demo.instructionInputQueue")
    instructionInputQueue.async {
        while !cameraServiceBrowser.readyToSendPacket {}
        captureNextBracket()
    }
}

temp()

NSApp.run()
