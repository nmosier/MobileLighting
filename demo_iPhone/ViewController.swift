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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        /*
        let fileManager = FileManager.default
        
        // Get contents in directory: '.' (current one)
        
        do {
            let files = try fileManager.contentsOfDirectory(atPath: Bundle.main.resourcePath!)
            print(files)
        }
        catch let error as NSError {
            print("Ooops! Something went wrong: \(error)")
        } */
        
        cameraService = CameraService()
        
        cameraService.startBroadcast()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}

