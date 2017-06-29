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
    @IBOutlet weak var whiteBalanceSlider: UISlider!
    
    @IBAction func screenTapped(_ sender: UITapGestureRecognizer) {
        let tapLoc: CGPoint = sender.location(in: nil)
        focusPointLabel.text = "(\(tapLoc.x), \(tapLoc.y))"
        focusPointLabel.drawText(in: videoPreviewView.frame)
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

