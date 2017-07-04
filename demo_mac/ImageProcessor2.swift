//
//  ImageProcessor2.swift
//  demo
//
//  Created by Nicholas Mosier on 6/28/17.
//  Copyright © 2017 Nicholas Mosier. All rights reserved.
//

import Foundation

func decodedImageHandler(_ decodedImPath: String, horizontal: Bool, projector: Int, position: Int) {
    let outdir = scenesDirectory+"/"+sceneName+"/"+computedSubdir+"/"+refinedSubdir+"/proj\(projector)/pos\(position)"
    do {
        try FileManager.default.createDirectory(atPath: outdir, withIntermediateDirectories: true, attributes: nil)
    } catch {
        return
    }
    refineDecodedIm(swift2Cstr(outdir), horizontal ? 1:0, swift2Cstr(decodedImPath))
}

func disparityMatchPair(projector: Int, leftpos: Int, rightpos: Int) {
    let refinedDirLeft = scenesDirectory+"/"+sceneName+"/"+computedSubdir+"/"+refinedSubdir+"/proj\(projector)/pos\(leftpos)"
    let refinedDirRight = scenesDirectory+"/"+sceneName+"/"+computedSubdir+"/"+refinedSubdir+"/proj\(projector)/pos\(rightpos)"
    let disparityDirLeft = scenesDirectory+"/"+sceneName+"/"+computedSubdir+"/"+disparitySubdir+"/proj\(projector)/pos\(leftpos)"
    let disparityDirRight = scenesDirectory+"/"+sceneName+"/"+computedSubdir+"/"+disparitySubdir+"/proj\(projector)/pos\(rightpos)"
    let fileman = FileManager.default
    do {
        try fileman.createDirectory(atPath: disparityDirLeft, withIntermediateDirectories: true, attributes: nil)
        try fileman.createDirectory(atPath: disparityDirRight, withIntermediateDirectories: true, attributes: nil)
    } catch {
        print("ImageProcessor2: could not create directory at either:\n\t\(disparityDirLeft)\n\t\(disparityDirRight)")
        return
    }
    disparitiesOfRefinedImgs(swift2Cstr(refinedDirLeft), swift2Cstr(refinedDirRight))
}
