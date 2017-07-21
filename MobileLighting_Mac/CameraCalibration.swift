//
//  CameraCalibration.swift
//  MobileLighting
//
//  Created by Nicholas Mosier on 7/20/17.
//  Copyright © 2017 Nicholas Mosier. All rights reserved.
//

import Foundation

let allowedCalibrationImageExtensions = ["PNG"]    // is it compatible with more?

// creates new image list from the contents of the specified directory,
// only adding files with extensions in the allowedCalibrationImageExtensions
// array
func createImageList(fromDir directory: String, toPath outpath: String) throws {
    let fileman = FileManager.default
    let imgfiles = try fileman.contentsOfDirectory(atPath: directory)
    var settings: String = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<opencv_storage>\n<images>\n"
    for name in imgfiles {
        if allowedCalibrationImageExtensions.contains((name.components(separatedBy: ".").last ?? "").uppercased()) {
            settings += "\"\(directory)/\(name)\"\n"
        }
    }
    settings += "</images>\n</opencv_storage>"
    try settings.write(toFile: outpath, atomically: true, encoding: String.Encoding.utf8)
}
