//
//  File.swift
//  MobileLighting_Mac
//
//  Created by Nicholas Mosier on 6/6/18.
//  Copyright © 2018 Nicholas Mosier. All rights reserved.
//

import Foundation

class DirectoryStructure {
    private var dirList: [String] {
        get {
            return [scenes, scene, orig, ambient, ambientBall, graycode, computed, decoded, refined, disparity, settings, calibSettings, metadata]
        }
    }
    let scenesDir: String
    public var currentScene: String
    
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
    
    init(scenesDir: String, currentScene: String) {
        self.scenesDir = scenesDir
        self.currentScene = currentScene
    }
    
    func createDirs() throws {
        for dir in dirList {
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
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
    
    func subdir(_ dir: String) -> String {
        return subdir(dir, proj: currentProj, pos: currentPos)
    }
}
