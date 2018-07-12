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
            return [scenes, scene, orig, ambient, ambientBall, computed, decoded, disparity, merged, calibComputed, intrinsicsPhotos, stereoPhotos, metadata, extrinsics, calibrationSettings, reprojected, merged2]
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
                return self.orig + "/" + "ambient"
            }
        }
    
        var ambientBall: String {
            get {
                return self.orig + "/" + "ambientBall"
            }
        }
    
        var calibration: String {
            get {
                return self.orig + "/" + "calibration"
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
    
                // deprecated, will be removed in future
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
    // this versino should be used in future -- does not organize by position pairs
                    func stereoPhotos(_ pos: Int) -> String {
                        return subdir(stereoPhotos, pos: pos)
                    }
    
            var calibrationSettings: String {
                get {
                    return self.calibration + "/" + "settings"
                }
            }
                var calibrationSettingsFile: String {
                    get {
                        return self.calibrationSettings + "/" + "calibration.yml"
                    }
                }
                var intrinsicsImageList: String {
                    get {
                        return self.calibrationSettings + "/" + "intrinsicsImageList.yml"
                    }
                }
                var stereoImageList: String {
                    get {
                        return self.calibrationSettings + "/" + "stereoImageList.yml"
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
                func decoded(_ rectified: Bool) -> String {
                    let subdir = "\(self.decoded)/\(rectified ? "rectified" : "unrectified")"
                    try! FileManager.default.createDirectory(atPath: subdir, withIntermediateDirectories: true, attributes: nil)
                    return subdir
                }
            func decoded(proj: Int, pos: Int, rectified: Bool) -> String {
                    let subdir = "\(self.decoded(rectified))/proj\(proj)/pos\(pos)"
                    try! FileManager.default.createDirectory(atPath: subdir, withIntermediateDirectories: true, attributes: nil)
                    return subdir
                }
//                func decodedFile(_ direction: Int) -> String {
//                    return decodedFile(direction, proj: currentProj, pos: currentPos)
//                }
//                func decodedFile(_ direction: Int, proj: Int, pos: Int) -> String {
//                    return subdir(decoded, proj: proj, pos: pos) + "/result\(direction).pfm"
//                }
//                func decodedDirLeft(_ direction: Int, proj: Int, pos: Int) -> String {
//                    let dir = subdir(decoded, proj: proj, pos: pos) + "/left"
//                    try! FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
//                    return dir
//                }
//                func decodedDirRight(_ direction: Int, proj: Int, pos: Int) -> String {
//                    let dir = subdir(decoded, proj: proj, pos: pos) + "/right"
//                    try! FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
//                    return dir
//                }
//                func rectifiedFileLeft(_ direction: Int, proj: Int, left: Int, right: Int) -> String {
//                    return subdir(decoded, proj: proj, pos: left) + "/result\(direction)-rectified\(left)\(right).pfm"
//                }
//                func rectifiedFileRight(_ direction: Int, proj: Int, left: Int, right: Int) ->String {
//                    return subdir(decoded, proj: proj, pos: right) + "/result\(direction)-rectified\(left)\(right).pfm"
//                }
    
//            var refined: String {
//                get {
//                    //return self.computed + "/" + "refined"
//                    return self.decoded
//                }
//            }
    
            var disparity: String {
                get {
                    return self.computed + "/" + "disparity"
                }
            }
                func disparity(_ rectified: Bool) -> String {
                    let subdir = "\(self.disparity)/\(rectified ? "rectified" : "unrectified")"
                    try! FileManager.default.createDirectory(atPath: subdir, withIntermediateDirectories: true, attributes: nil)
                    return subdir
                }
    
                func disparity(proj: Int, pos: Int, rectified: Bool) -> String {
                    return subdir(self.disparity(rectified), proj: proj, pos: pos)
                }
    
            var merged: String {
                get {
                    return self.computed + "/" + "merged"
                }
            }
                func merged(_ rectified: Bool) -> String {
                    let subdir = "\(self.merged)/\(rectified ? "rectified" : "unrectified")"
                    try! FileManager.default.createDirectory(atPath: subdir, withIntermediateDirectories: true, attributes: nil)
                    return subdir
                }
                    func merged(pos: Int, rectified: Bool) -> String {
                        let subdir = self.merged(rectified) + "/" + "pos\(pos)"
                        try! FileManager.default.createDirectory(atPath: subdir, withIntermediateDirectories: true, attributes: nil)
                        return subdir
                    }
    
    var reprojected: String {
        get {
            return self.computed + "/" + "reprojected"
        }
    }

    func reprojected(proj: Int, pos: Int) -> String {
        return subdir(self.reprojected, proj: proj, pos: pos)
    }
    
    var merged2: String {
        return self.computed + "/" + "merged2"
    }
    func merged2(_ pos: Int) -> String {
        return subdir(merged2, pos: pos)
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
