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
    let blendRadius: Double
    let acceleration: Double
    let velocity: Double
    
    var duration: Double {
        get {
            return timestep * Double(waypoints.count - 1)
        }
    }
    
    var script: String {
        var script_ = "def Trajectory():\n"
        for point in path {
            script_ += "movel(\(point), a=\(acceleration), v=\(velocity), r=\(blendRadius), t=\(timestep))\n"
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
        let points = positionsTmp.compactMap {
            return $0.string
        }
        self.path = points // need to use copy so that can lookup waypoints before object intialized
        
        guard let waypointsTmp = yaml[Yaml.string("waypoints")].array else {
            fatalError("waypoints must be provided as array.")
        }
        self.waypoints = waypointsTmp.compactMap {
            if let index = $0.int {
                guard index >= 0 && index < points.count else {
                    return nil
                }
                return points[index]
            } else {
                return $0.string
            }
        }
        
        guard let blendRadius_ = yaml[Yaml.string("blendRadius")].double else {
            fatalError("trajectory: blendRadius must be provided for recreating trajectory.")
        }
        self.blendRadius = blendRadius_
        
        guard let acceleration_ = yaml[Yaml.string("acceleration")].double else {
            fatalError("trajectory: robot acceleration must be specified.")
        }
        guard let velocity_ = yaml[Yaml.string("velocity")].double else {
            fatalError("trajectory: robot velocity must be specified.")
        }
        self.acceleration = acceleration_
        self.velocity = velocity_
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
    
    static var format: Yaml {
        get {
            var mainDict = [Yaml:Yaml]()
            mainDict[Yaml.string("trajectory")] = Yaml.array([Yaml](repeating: Yaml.string(""), count: 3))
            mainDict[Yaml.string("waypoints")] = Yaml.array([Yaml](repeating: Yaml.string(""), count: 3))
            mainDict[Yaml.string("timestep")] = Yaml.double(0.25)
            mainDict[Yaml.string("blendRadius")] = Yaml.double(0.1)
            mainDict[Yaml.string("acceleration")] = Yaml.double(0.4)
            mainDict[Yaml.string("velocity")] = Yaml.double(0.4)
            return Yaml.dictionary(mainDict)
        }
    }
    
    static func create(_ dirStruc: DirectoryStructure) throws {
        let yml = Trajectory.format
        let str = try yml.save()
        try str.write(toFile: dirStruc.settings + "/trajectory.yml", atomically: true, encoding: .ascii)
    }
}
