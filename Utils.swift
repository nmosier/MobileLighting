//
//  Utils.swift
//  MobileLighting
//
//  Created by Nicholas Mosier on 7/18/17.
//  Copyright © 2017 Nicholas Mosier. All rights reserved.
//

import Foundation

func swift2Cstr(_ str: String) -> UnsafeMutablePointer<Int8> {
    let nsstr = str as NSString
    return UnsafeMutablePointer<Int8>(mutating: nsstr.utf8String!)
}
