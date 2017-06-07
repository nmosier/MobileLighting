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
    
    var codeDrawer: BinaryCodeDrawer?
    var currentCodeBit: UInt?
    var currentSystem: BinaryCodeSystem?
    
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
        self.codeDrawer = BinaryCodeDrawer(context: self.fullscreenWindow.graphicsContext!, frame: screen.frame)
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
        
        if let image = image {
            context.draw(image, in: self.frame)
        } else if let codeDrawer = codeDrawer, let currentCodeBit = currentCodeBit, let currentSystem = currentSystem {
            codeDrawer.drawCode(forBit: currentCodeBit, system: currentSystem, positionLimit: (currentSystem == BinaryCodeSystem.MinStripeWidthCode) ? 1024 : nil)
        }
    }
    
    func drawImage(_ image: CGImage) {
        self.image = image
        NSGraphicsContext.setCurrent(self.fullscreenWindow.graphicsContext)
        let context = self.fullscreenWindow.graphicsContext!.cgContext
        context.draw(image, in: self.frame)
        self.setNeedsDisplay(self.frame)
    }
    
    func configureDisplaySettings(horizontal: Bool = false, inverted: Bool = false) {
        guard let codeDrawer = codeDrawer else {
            Swift.print("FullscreenWindow: cannot configure display settings — binary code drawer not yet configured.")
            return
        }
        
        (codeDrawer.drawHorizontally, codeDrawer.drawInverted) = (horizontal, inverted)
    }
    
    func displayBinaryCode(forBit bit: UInt, system: BinaryCodeSystem) {
        NSGraphicsContext.setCurrent(self.fullscreenWindow.graphicsContext)
        
        currentCodeBit = bit
        currentSystem = system
        self.setNeedsDisplay(self.frame)
    }
    
    func displayGrayCode(forBit bit: UInt) {
        NSGraphicsContext.setCurrent(self.fullscreenWindow.graphicsContext)
        guard let graphicsContext = NSGraphicsContext.current() else {
            Swift.print("Cannot draw fullscreen window content: current graphics context is nil.")
            return
        }
        
        currentCodeBit = bit
        self.setNeedsDisplay(self.frame)
    }
}
