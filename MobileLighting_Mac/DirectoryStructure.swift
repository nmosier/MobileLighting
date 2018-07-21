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
            return [scenes, scene, orig, ambient, ambientBall, computed, decoded, disparity, merged, calibComputed, intrinsicsPhotos, stereoPhotos, metadata, extrinsics, calibrationSettings, reprojected, merged2, ambientPhotos, ambientVideos]
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
    
        private var ambient: String {
            get {
                return self.orig + "/" + "ambient"
            }
        }
    
    enum PhotoMode: String {
        case normal
        case flash
        case torch
    }
    
    var ambientPhotos: String {
        get {
            return self.ambient + "/" + "photos"
        }
    }
    
            func ambientPhotos(_ mode: PhotoMode) -> String {
                let subdir =  "\(ambientPhotos)/\(mode.rawValue)"
                try! FileManager.default.createDirectory(atPath: subdir, withIntermediateDirectories: true, attributes: nil)
                return subdir
            }
    
            func ambientPhotos(pos: Int, mode: PhotoMode) -> String {
                return subdir(self.ambientPhotos(mode), pos: pos)
            }
    
            func ambientPhotos(pos: Int, exp: Int, mode: PhotoMode) -> String {
                let path = ambientPhotos(pos: pos, mode: mode) + "/exp\(exp)"
                        try! FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
                        return path
                    }
            
            var ambientVideos: String {
                get {
                    return self.ambient + "/" + "videos"
                }
            }
    
    enum VideoMode: String {
        case normal
        case torch
    }
    
    func ambientVideos(_ mode: VideoMode) -> String {
        let subdir = "\(self.ambientVideos)/\(mode.rawValue)"
        try! FileManager.default.createDirectory(atPath: subdir, withIntermediateDirectories: true, attributes: nil)
        return subdir
    }
    
    func ambientVideos(exp: Int, mode: VideoMode) -> String {
        let subdir = "\(self.ambientVideos(mode))/exp\(exp)"
                try! FileManager.default.createDirectory(atPath: subdir, withIntermediateDirectories: true, attributes: nil)
                return subdir
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
    
    func decoded(proj: Int, rectified: Bool) -> String {
        let subdir = "\(self.decoded(rectified))/proj\(proj)"
        try! FileManager.default.createDirectory(atPath: subdir, withIntermediateDirectories: true, attributes: nil)
        return subdir
    }
    
            func decoded(proj: Int, pos: Int, rectified: Bool) -> String {
                let subdir = "\(self.decoded(proj: proj, rectified: rectified))/pos\(pos)"
                    try! FileManager.default.createDirectory(atPath: subdir, withIntermediateDirectories: true, attributes: nil)
                    return subdir
                }
    
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

            func extrinsicsYML(left: Int, right: Int) -> String {
                return self.extrinsics + "/" + "extrinsics\(left)\(right).yml"
            }
    
    
    
            var metadata: String {
                get {
                    return self.computed + "/" + "metadata"
                }
            }
                func metadataFile(_ direction: Int, proj: Int, pos: Int) -> String {
                    return subdir(metadata, proj: proj, pos: pos) + "/metadata\(direction).yml"
                }
    
    
    //MARK: utility functions
    func createDirs() throws {
        for dir in dirList {
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    
    // subdir -- get subdirectory of provided directory path
    // indexed to current/provided projector and position
    private func subdir(_ dir: String, proj: Int, pos: Int) -> String {
        let subdir = self.subdir(dir, proj: proj) + "/" + "pos\(pos)"
        try! FileManager.default.createDirectory(atPath: subdir, withIntermediateDirectories: true, attributes: nil)
        return subdir
    }
    private func subdir(_ dir: String, proj: Int) -> String {
        let subdir = dir + "/" + "proj\(proj)"
        try! FileManager.default.createDirectory(atPath: subdir, withIntermediateDirectories: true, attributes: nil)
        return subdir
    }
    private func subdir(_ dir: String, pos: Int) -> String {
        let subdir = dir + "/" + "pos\(pos)"
        try! FileManager.default.createDirectory(atPath: subdir, withIntermediateDirectories: true, attributes: nil)
        return subdir
    }
}
