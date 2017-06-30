//
//  ViewController.swift
//  demo_iPhone
//
//  Created by Nicholas Mosier on 5/26/17.
//  Copyright © 2017 Nicholas Mosier. All rights reserved.
//

import UIKit
import CocoaAsyncSocket
import AVFoundation
import Photos

class ViewController: UIViewController {
    var cameraService: CameraService!
    @IBOutlet var videoPreviewView: VideoPreviewView!
    @IBOutlet weak var focusPointLabel: UILabel!
    @IBOutlet weak var lockExposureSwitch: UISwitch!
    @IBOutlet weak var lockFocusSwitch: UISwitch!
    
    
    @IBAction func updateExposureMode(_ sender: UISwitch) {
        let mode: AVCaptureExposureMode = sender.isOn ? .locked : .autoExpose
        do {
            try self.cameraService.cameraController.configureCaptureDevice(exposureMode: mode)
        } catch {
            // failed — set back to prev. state
            sender.setOn(!sender.isOn, animated: false)
        }
    }
    
    @IBAction func updateFocusMode(_ sender: UISwitch) {
        let mode: AVCaptureFocusMode = sender.isOn ? .locked : .autoFocus
        do {
            try self.cameraService.cameraController.configureCaptureDevice(focusMode: mode)
        } catch {
            sender.setOn(!sender.isOn, animated: false)
        }
    }
    
    // called when screen is tapped
    @IBAction func updateFocus(_ sender: UITapGestureRecognizer) {
        guard sender.state == .ended && !lockFocusSwitch.isOn else {
            return
        }
        
        let rawPos = sender.location(in: videoPreviewView)   // location in base coordinate system
        let focusPoint = videoPreviewView.videoPreviewLayer.captureDevicePointOfInterest(for: rawPos)
        print("ViewController: focusing to point: (\(focusPoint.x), \(focusPoint.y))")
        do {
            try self.cameraService.cameraController.configureCaptureDevice(focusMode: .autoFocus, focusPointOfInterest: focusPoint)
        } catch {
            lockFocusSwitch.setOn(false, animated: false)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.cameraService = CameraService()
        self.videoPreviewView.session = self.cameraService.cameraController.captureSession
        
        cameraService.startBroadcast()
        
        // test bridging header
        print("testing bridging header...")
        print("CShape width: \(getCShapeWidth())")
        getCShapeWidth()
        
        // testing ActiveLighting bridging header
        var cmd = "./activeLighting".utf8CString
        
        var ptr = UnsafeMutableRawPointer(mutating: &cmd)
        var cmdptr = ptr.assumingMemoryBound(to: Int8.self)
        var ptr2 = UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>.allocate(capacity: 1)
        defer {
            ptr2.deallocate(capacity: 1)
        }
        ptr2.pointee = cmdptr
        
        //activeLighting(1, ptr2)
        //ALmain2(1, ptr2)
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}

