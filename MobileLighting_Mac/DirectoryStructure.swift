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
            return [scenes, scene, orig, ambient, ambientBall, computed, decoded, refined, disparity, calibComputed, intrinsicsPhotos, extrinsics, metadata, extrinsics]
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
            var intrinsicsPhotos: String {
                get {
                    return self.calibration + "/" + "intrinsics"
                }
            }
            var stereoPhotos: String {
                get {
                    return self.calibration + "/" + "stereo"
                }
            }
                func stereoPhotosPair(left: Int, right: Int) -> String {
                    let subdir = self.stereoPhotos + "/" + "pos\(left)\(right)"
                    try! FileManager.default.createDirectory(atPath: subdir, withIntermediateDirectories: true, attributes: nil)
                    return subdir
                }
                    func stereoPhotosPairLeft(left: Int, right: Int) -> String {
                        return subdir(stereoPhotosPair(left: left, right: right), pos: left)
                    }
                    func stereoPhotosPairRight(left: Int, right: Int) -> String {
                        return subdir(stereoPhotosPair(left: left, right: right), pos: right)
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
    
            var rectified: String {
                get {
                    return self.computed + "/" + "rectified"
                }
            }
    
    
            var disparity: String {
                get {
                    return self.computed + "/" + "disparity"
                }
            }
                func disparityPfmFile(l leftpos: Int, r rightpos: Int, proj: Int, direction: Int) -> String {
                    return subdir(disparity, proj: proj, pos: leftpos) + "/" + "disp\(leftpos)\(rightpos)-\(direction).pfm"
                }
    
            var calibComputed: String {
                get {
                    return self.computed + "/" + "calibration"
                }
            }
    
            var intrinsicsYML: String {
                get {
                    return self.calibComputed + "/" + "intrinsics.yml"
                }
            }
    
            var extrinsics: String {
                get {
                    return self.calibComputed + "/" + "extrinsics"
                }
            }
            func extrinsicsSubdir(left: Int, right: Int) -> String {
                let subdir = self.extrinsics + "/pos\(left)\(right)"
                try! FileManager.default.createDirectory(atPath: subdir, withIntermediateDirectories: true, attributes: nil)
                return subdir
            }
            func extrinsicsYML(left: Int, right: Int) -> String {
                return self.extrinsicsSubdir(left: left, right: right) + "/" + "extrinsics.yml"
            }
    
    
    
    
            var metadata: String {
                get {
                    return self.computed + "/" + "metadata"
                }
            }
                func metadataFile(_ direction: Int, proj: Int, pos: Int) -> String {
                    return subdir(metadata, proj: proj, pos: pos) + "/metadata\(direction).yml"
                }
                func metadataFile(_ direction: Int) -> String {
                    return subdir(metadata) + "/metadata\(direction).yml"
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
