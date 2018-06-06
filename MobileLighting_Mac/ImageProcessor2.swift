//
//  ImageProcessor2.swift
//  demo
//
//  Created by Nicholas Mosier on 6/28/17.
//  Copyright © 2017 Nicholas Mosier. All rights reserved.
//

import Foundation
import Yaml

func decodedImageHandler(_ decodedImPath: String, horizontal: Bool, projector: Int, position: Int) {
    let outdir = dirStruc.subdir(dirStruc.refined, proj: projector, pos: position) //scenesDirectory+"/"+sceneName+"/"+computedSubdir+"/"+refinedSubdir+"/proj\(projector)/pos\(position)"
    //makeDir(outdir)
    let completionHandler: () -> Void = {
        let direction: Int = horizontal ? 1 : 0
        let filepath = dirStruc.metadataFile(direction)
        do {
            let metadataStr = try String(contentsOfFile: filepath)
            let metadata: Yaml = try Yaml.load(metadataStr)
            if let angle: Double = metadata.dictionary?[Yaml.string("angle")]?.double {
                refineDecodedIm(swift2Cstr(outdir), horizontal ? 1:0, swift2Cstr(decodedImPath), angle)
            } else {
                print("refine error: could not load angle (double) from YML file.")
            }
        } catch {
            print("refine error: could not load metadata file.")
        }
    }
    photoReceiver.receiveSceneMetadata(completionHandler: completionHandler)
}

//MARK: disparity matching functions
// uses bridged C++ code from ActiveLighting image processing pipeline
// NOTE: this decoding step is not yet automated; it must manually be executed from
//    the main command-line user input loop

// computes & saves disparity maps for images of the given image position pair taken with the given projector
func disparityMatch(projector: Int, leftpos: Int, rightpos: Int) {
    let refinedDirLeft = dirStruc.subdir(dirStruc.refined, proj: projector, pos: leftpos)//scenesDirectory+"/"+sceneName+"/"+computedSubdir+"/"+refinedSubdir+"/proj\(projector)/pos\(leftpos)"
    let refinedDirRight = dirStruc.subdir(dirStruc.refined, proj: projector, pos: rightpos) // scenesDirectory+"/"+sceneName+"/"+computedSubdir+"/"+refinedSubdir+"/proj\(projector)/pos\(rightpos)"
    //let disparityDirLeft = dirStruc.subdir(dirStruc.disparity, proj: projector, pos: leftpos) //scenesDirectory+"/"+sceneName+"/"+computedSubdir+"/"+disparitySubdir+"/proj\(projector)"
    //let disparityDirRight = dirStruc.subdir(dirStruc.disparity, proj: projector, pos: rightpos) // scenesDirectory+"/"+sceneName+"/"+computedSubdir+"/"+disparitySubdir+"/proj\(projector)"
    let disparityFileLeft = dirStruc.disparityFloFile(l: leftpos, r: rightpos, proj: projector)//"disp\(leftpos)\(rightpos).flo"
    let disparityFileRight = dirStruc.disparityFloFile(l: rightpos, r: leftpos, proj: projector) //"disp\(rightpos)\(leftpos).flo"
    /*
    let fileman = FileManager.default
    do {
        try fileman.createDirectory(atPath: disparityDirLeft, withIntermediateDirectories: true, attributes: nil)
        try fileman.createDirectory(atPath: disparityDirRight, withIntermediateDirectories: true, attributes: nil)
    } catch {
        print("ImageProcessor2: could not create directory at either:\n\t\(disparityDirLeft)\n\t\(disparityDirRight)")
        return
    }
 */
    //disparitiesOfRefinedImgs(swift2Cstr(refinedDirLeft), swift2Cstr(refinedDirRight))
    disparitiesOfRefinedImgs(swift2Cstr(refinedDirLeft), swift2Cstr(refinedDirRight),
                             swift2Cstr(disparityFileLeft),
                             swift2Cstr(disparityFileRight),
                             0, 0, 0, 0)
    
    
}

// computes & saves disparity maps for all positions taken for the given projector
func disparityMatch(projector: Int) {
    let dir = scenesDirectory+"/"+sceneName+"/"+computedSubdir+"/"+refinedSubdir+"/proj\(projector)"
    let fileman = FileManager.default
    let subdirs: [String]
    do {
        subdirs = try fileman.contentsOfDirectory(atPath: dir)
    } catch {
        print("disparityMatch: error enumerating subpaths of directory \(dir)")
        return
    }
    let validDirs = subdirs.filter { subdir in
        return subdir.hasPrefix("pos")
    }
    for pos in 0..<validDirs.count-1 {    // 'posX'
        disparityMatch(projector: projector, leftpos: pos, rightpos: pos+1)
    }
}

// computes & saves disparity maps for all adjacent positions taken from all projectors
func disparityMatch() {
    let dir = scenesDirectory+"/"+sceneName+"/"+computedSubdir+"/"+refinedSubdir
    let fileman = FileManager.default
    let subdirs: [String]
    do {
        subdirs = try fileman.subpathsOfDirectory(atPath: dir)
    } catch {
        print("disparityMatch: error enumerating subpaths of directory \(dir)")
        return
    }
    
    for subdir in subdirs {
        guard subdir.hasPrefix("proj") else { continue }
        var subdir2 = subdir
        subdir2.removeSubrange(subdir2.range(of: "proj")!)
        guard let projID = Int(subdir2) else {
            continue
        }
        disparityMatch(projector: projID)
    }
}
