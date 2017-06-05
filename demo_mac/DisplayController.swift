//
//  DisplayController.swift
//  demo_mac
//
//  Created by Nicholas Mosier on 6/1/17.
//  Copyright © 2017 Nicholas Mosier. All rights reserved.
//

import Cocoa
import CoreGraphics

class DisplayController: NSWindowController {
    //MARK: Properties
    var windows = [FullscreenWindow]()  // windows currently being displayed
    
    //MARK: Static functions
    
    // createCGImage(filePath:)
    //  -filePath: file path (String)
    //  -returns CGImage object, which can directly be drawn by CGContexts (from Quartz 2D graphics library)
    func createCGImage(filePath: String) -> CGImage {
        let url = NSURL(fileURLWithPath: filePath)
        let dataProvider = CGDataProvider(url: url)
        return CGImage(jpegDataProviderSource: dataProvider!, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    }
    
    
    //MARK: Functions
    
    // createNewWindow(on:)
    //  -on: NSScreen -> screen to create new window on
    //  creates & displays new window and adds to list of FullscreenWindows
    func createNewWindow(on screen: NSScreen) {
        let newWindow = FullscreenWindow(on: screen)
        windows.append(newWindow)
    }
}
