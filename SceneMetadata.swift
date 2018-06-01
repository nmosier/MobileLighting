//
//  Metadata.swift
//  MobileLighting_iPhone
//
//  Created by Nicholas Mosier on 5/30/18.
//  Copyright © 2018 Nicholas Mosier. All rights reserved.
//

import Foundation

class SceneMetadata {    
    var focus: Float!
    var exposureDurations: [Double]!
    //var exposureISOs: [Double]!
    var angle: Double!
    
    func getMetadataYAMLData() -> NSData {
        var out: String = String()
        out += "focus:\t" + String(self.focus) + "\n"   // focus
        out += "exposureDurations:\t\n"
        for exposureDuration in self.exposureDurations  {
            out += "\t- " + String(exposureDuration) + "\n"
        }
        out += "angle:\t" + String(angle) + "\n"
        
        guard let data: NSData = out.data(using: .utf8) as  NSData? else {
            fatalError("SceneMetadata error: cannot get data from string")
        }
        return data
    }
    
    func saveMetadataData(_ data: NSData, toFile filepath: String) {
        let dir: String = filepath.split(separator: "/").dropLast().joined(separator: "/")
        do {
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
            //try data.write(to: filepath, atomically: true)
            data.write(toFile: filepath, atomically: true)
        } catch let file_error as NSError {
            print(file_error.localizedDescription)
        }
    }
}
