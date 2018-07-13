//
//  Trajectory.swift
//  MobileLighting_Mac
//
//  Created by Nicholas Mosier on 7/13/18.
//  Copyright © 2018 Nicholas Mosier. All rights reserved.
//

import Foundation
import Yaml

class Trajectory {
    let path: [String]
    let timestep: Double
    let waypoints: [String]
    
    var duration: Double {
        get {
            return timestep * Double(waypoints.count - 1)
        }
    }
    
    var script: String {
        var script_ = "def Trajectory():\n"
        for point in path {
            script_ += "movel(\(point), 2.0, 0.4, \(timestep))\n"
        }
        script_ += "end\n"
        return script_
    }
    
    init(_ filepath: String) {
        guard let settingsData = FileManager.default.contents(atPath: filepath) else {
            fatalError("path \(filepath) does not exist.")
        }
        guard let settingsStr = String(data: settingsData, encoding: .ascii), let yaml = try? Yaml.load(settingsStr) else {
            fatalError("invalid YAML format of trajectory settings file.")
        }
        guard let timestep = yaml[Yaml.string("timestep")].double else {
            fatalError("trajectory timestep invalid.")
        }
        self.timestep = timestep
        
        guard let positionsTmp = yaml[Yaml.string("trajectory")].array else {
            fatalError("positions must be proivded as array.")
        }
        let points = positionsTmp.flatMap {
            return $0.string
        }
        self.path = points // need to use copy so that can lookup waypoints before object intialized
        
        guard let waypointsTmp = yaml[Yaml.string("waypoints")].array else {
            fatalError("waypoints must be provided as array.")
        }
        self.waypoints = waypointsTmp.flatMap {
            if let index = $0.int {
                guard index >= 0 && index < points.count else {
                    return nil
                }
                return points[index]
            } else {
                return $0.string
            }
        }
        
    }
    
    
    // moveToStart -- move to starting position of path
    // is synchronous -- don't have to worry about timing
    func moveToStart() {
        let timedelay = 5.0
        guard let startpos = path.first else {
            print("trajectory is empty.")
            return
        }
        var command = *"movej(\(startpos), 2.0, 0.3)\n"//, \(timedelay))\n"
        sendscript(&command)
//        usleep(UInt32(timedelay * 1e6))
    }
    
    func executeScript() {
        var cScript = *script
        sendscript(&cScript)
//        usleep(UInt32(self.duration * 1e6))
    }
}
