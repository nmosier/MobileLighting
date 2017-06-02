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
    
    func createNewWindow(on screen: NSScreen) {
        let newWindow = FullscreenWindow(on: screen)
        windows.append(newWindow)
    }
}
