//
//  DirectoryStructure.swift
//  MobileLighting_Mac
//
//  Created by Nicholas Mosier on 6/6/18.
//

import Foundation

// manages the directory structure of the MobileLighting project
class DirectoryStructure {
    let scenesDir: String
    public var currentScene: String
    
    init(scenesDir: String, currentScene: String) {
        self.scenesDir = scenesDir
        self.currentScene = currentScene
    }
    
    private var dirList: [String] {
        get {
            return [scenes, scene, orig, ambient, ambientBall, graycode, computed, decoded, refined, disparity, settings, calibSettings, metadata]
        }
    }
    
    // MARK: generated directory paths
    var scenes: String {
        get {
            return scenesDir
        }
    }
    var scene: String {
        return [scenesDir, currentScene].joined(separator: "/")
    }
    
    var orig: String {
        get {
            return self.scene + "/" + "orig"
        }
    }
    
    var ambient: String {
        get {
            return self.scene + "/" + "ambient"
        }
    }
    
    var ambientBall: String {
        get {
            return self.scene + "/" + "ambientBall"
        }
    }
    
    var calibration: String {
        get {
            return self.scene + "/" + "calibration"
        }
    }
    func calibrationPos(_ pos: Int) -> String {
        return subdir(self.calibration, pos: pos)
    }
    
    var graycode: String {
        get {
            return self.scene + "/" + "graycode"
        }
    }
    
    var computed: String {
        get {
            return self.scene + "/" + "computed"
        }
    }
    
    var prethresh: String {
        get {
            return self.computed + "/" + "prethresh"
        }
    }
    
    var thresh: String {
        get {
            return self.computed + "/" + "thresh"
        }
    }
    
    var decoded: String {
        get {
            return self.computed + "/" + "decoded"
        }
    }
    func decodedFile(_ direction: Int) -> String {
        return decodedFile(direction, proj: currentProj, pos: currentPos)
    }
    func decodedFile(_ direction: Int, proj: Int, pos: Int) -> String {
        return subdir(decoded, proj: proj, pos: pos) + "/result\(direction).pfm"
    }
    
    var refined: String {
        get {
            return self.computed + "/" + "refined"
        }
    }
    
    var disparity: String {
        get {
            return self.computed + "/" + "disparity"
        }
    }
    func disparityFloFile(l leftpos: Int, r rightpos: Int) -> String {
        return disparityFloFile(l: leftpos, r: rightpos, proj: currentProj)
    }
    func disparityFloFile(l leftpos: Int, r rightpos: Int, proj: Int) -> String {
        return subdir(disparity, proj: proj, pos: leftpos) + "/" + "disp\(leftpos)\(rightpos).flo"
    }
    func disparityPfmFile(l leftpos: Int, r rightpos: Int, proj: Int, direction: Int) -> String {
        return subdir(disparity, proj: proj, pos: leftpos) + "/" + "disp\(leftpos)\(rightpos)-\(direction).pfm"
    }
    
    var settings: String {
        get {
            return self.scene + "/" + "settings"
        }
    }
    
    var calibSettings: String {
        get {
            return self.settings + "/" + "calibration"
        }
    }
    
    var metadata: String {
        get {
            return self.computed + "/" + "metadata"
        }
    }
    func metadataFile(_ direction: Int, proj: Int, pos: Int) -> String {
        return subdir(metadata, proj: proj, pos: pos) + "/metadata-\(direction).yml"
    }
    func metadataFile(_ direction: Int) -> String {
        return subdir(metadata) + "/metadata-\(direction).yml"
    }
    
    
    //MARK: utility functions
    func createDirs() throws {
        for dir in dirList {
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    
    // subdir -- get subdirectory of provided directory path
    // indexed to current/provided projector and position
    func subdir(_ dir: String, proj: Int, pos: Int) -> String {
        let subdir = self.subdir(dir, proj: proj) + "/" + "pos\(pos)"
        try! FileManager.default.createDirectory(atPath: subdir, withIntermediateDirectories: true, attributes: nil)
        return subdir
    }
    func subdir(_ dir: String, proj: Int) -> String {
        let subdir = dir + "/" + "proj\(proj)"
        try! FileManager.default.createDirectory(atPath: subdir, withIntermediateDirectories: true, attributes: nil)
        return subdir
    }
    func subdir(_ dir: String, pos: Int) -> String {
        let subdir = dir + "/" + "pos\(pos)"
        try! FileManager.default.createDirectory(atPath: subdir, withIntermediateDirectories: true, attributes: nil)
        return subdir
    }
    func subdir(_ dir: String) -> String {
        return subdir(dir, proj: currentProj, pos: currentPos)
    }
}
