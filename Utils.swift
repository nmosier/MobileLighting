//
//  Utils.swift
//  MobileLighting
//
//  Created by Nicholas Mosier on 7/18/17.
//  Copyright © 2017 Nicholas Mosier. All rights reserved.
//

import Foundation
import CoreVideo

func swift2Cstr(_ str: String) -> UnsafeMutablePointer<Int8> {
    let nsstr = str as NSString
    return UnsafeMutablePointer<Int8>(mutating: nsstr.utf8String!)
}

func makeDir(_ str: String) -> Void {
    do {
        try FileManager.default.createDirectory(atPath: str, withIntermediateDirectories: true, attributes: nil)
    } catch {
        print("make dir - error - could not make directory.")
    }
}

let lockFlags = CVPixelBufferLockFlags(rawValue: 0) // read & write
