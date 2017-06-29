//
//  ImageProcessor2.swift
//  demo
//
//  Created by Nicholas Mosier on 6/28/17.
//  Copyright © 2017 Nicholas Mosier. All rights reserved.
//

import Foundation

func decodedImageHandler(_ decodedImPath: String, horizontal: Bool, projector: Int) {
    let outdir = scenesDirectory+"/"+sceneName+"/"+computedSubdir+"/"+refinedSubdir+"/proj\(projector)"
    do {
        try FileManager.default.createDirectory(atPath: outdir, withIntermediateDirectories: true, attributes: nil)
    } catch {
        return
    }
    refineDecodedIm(swift2Cstr(outdir), horizontal ? 1:0, swift2Cstr(decodedImPath))
}

