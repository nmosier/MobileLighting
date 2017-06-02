//
//  FullscreenWindowView.swift
//  demo_mac
//
//  Created by Nicholas Mosier on 6/1/17.
//  Copyright © 2017 Nicholas Mosier. All rights reserved.
//

import Cocoa
import Foundation
import CoreGraphics

class FullscreenWindow: NSView {
    var fullscreenWindow: NSWindow!
    var screen: NSScreen!
    var image: CGImage?
    
    init(on screen: NSScreen) {
        super.init(frame: screen.frame)
        
        let contentRect = NSMakeRect(screen.frame.minX, screen.frame.minY, screen.frame.maxX-screen.frame.minX, screen.frame.maxY-screen.frame.minY)
        let window = NSWindow(contentRect: contentRect, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = self
        window.isOpaque = true
        window.isMovableByWindowBackground = true
        window.makeKeyAndOrderFront(nil)
        window.orderFront(nil)
        
        self.fullscreenWindow = window
        self.screen = screen
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // make sure correct graphics context has been set
        NSGraphicsContext.setCurrent(self.fullscreenWindow.graphicsContext)
        guard let graphicsContext = NSGraphicsContext.current() else {
            Swift.print("Cannot draw fullscreen window content: current graphics context is nil.")
            return
        }
        
        let context: CGContext = graphicsContext.cgContext
        context.setFillColor(CGColor.white)
        context.fill(self.frame)
        
        if let image = image {
            context.draw(image, in: self.frame)
        }
    }
    
    func drawImage(_ image: CGImage) {
        self.image = image
        NSGraphicsContext.setCurrent(self.fullscreenWindow.graphicsContext)
        let context = self.fullscreenWindow.graphicsContext!.cgContext
        context.draw(image, in: self.frame)
        self.setNeedsDisplay(self.frame)
    }
}
