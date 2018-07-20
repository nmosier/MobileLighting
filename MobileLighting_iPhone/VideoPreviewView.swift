//
//  VideoPreviewView.swift
//  demo
//
//  Created by Nicholas Mosier on 6/22/17.
//  Copyright © 2017 Nicholas Mosier. All rights reserved.
//

import UIKit
import AVFoundation

class VideoPreviewView: UIView {
    @IBOutlet weak var focusPointLabel: UILabel!

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    
    var session: AVCaptureSession? {
        get {
            return videoPreviewLayer.session
        }
        set {
            videoPreviewLayer.session = newValue
            
        }
    }
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    private var orientationMap: [UIDeviceOrientation : AVCaptureVideoOrientation] = [
        .portrait : .portrait,
        .portraitUpsideDown : .portraitUpsideDown,
        .landscapeLeft : .landscapeLeft,
        .landscapeRight: .landscapeRight
    ]
    
    func updateOrientation() {
        if let connection = videoPreviewLayer.connection {
            let deviceOrientation = UIDevice.current.orientation
            guard let displayOrientation = orientationMap[deviceOrientation],
                deviceOrientation.isPortrait || deviceOrientation.isLandscape else {
                    return
            }
//            print("display orientation = \(displayOrientation)")
            connection.videoOrientation = displayOrientation
//            connection.videoOrientation = .portrait
        }
    }

}
