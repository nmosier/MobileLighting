//
//  GrayCode.swift
//  demo
//
//  Created by Nicholas Mosier on 6/20/17.
//  Copyright © 2017 Nicholas Mosier. All rights reserved.
//

import Foundation

func grayCodeArray(forBit bit: Int, size: Int) -> [Bool] {
    var array = [Bool]()
    array.reserveCapacity(Int(size))
    
    for i in 0..<size {
        array.append(getBit(encodeGrayCode(of: i), bit: bit))
    }
    return array
}

func encodeGrayCode(of pos: Int) -> Int {
    return pos ^ (pos >> 1)
}

// algorithm from http://www.cs.brandeis.edu/~storer/JimPuzzles/MANIP/ChineseRings/READING/GrayCodesWikipedia.pdf, pg. 6
func decodeGrayCode(of code: UInt32) -> UInt32 {
    var pos: UInt32 = code
    var ish: UInt32 = 1
    var idiv: UInt32
    
    while true {
        idiv = pos >> ish
        pos ^= idiv
        if idiv <= 1 || ish == 32 {
            return pos
        }
        ish <<= 1
    }
    
}

func getBit(_ n: Int, bit: Int) -> Bool {
    return (n & (1 << bit)) != 0
}
