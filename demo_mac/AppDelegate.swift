//
//  AppDelegate.swift
//  demo_mac
//
//  Created by Nicholas Mosier on 5/26/17.
//  Copyright © 2017 Nicholas Mosier. All rights reserved.
//

import Cocoa

//@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    //@IBOutlet weak var application: NSApplication!
    

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        //application.presentationOptions = NSApplicationPresentationOptions.fullScreen   // fullscreen mode
        
        //NSMenu.setMenuBarVisible(false)
        //print("SET MENU BAR TO FALSE")
        //print("MENU BAR IS VISIBLE: \(NSMenu.menuBarVisible())")
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}
