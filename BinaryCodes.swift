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


//MARK: Min Stripe Width Binary Codes
var minStripeWidthCodeBitArrays: [[Bool]]?   // contains minstripewidth code bit arrays from minsSWcode.dat

// for displaying purposes only
func loadMinStripeWidthCodes(filepath: String = "/Users/nicholas/OneDrive - Middlebury College/Summer Research 2017/demo-mobile-scene-capture/demo_mac/minStripeWidthCodes.dat", codeCount: Int = 10, codeLength: Int = 1024) throws {
    let fileURL = URL(fileURLWithPath: filepath)
    let codeData = try Data(contentsOf: fileURL)
    
    print("BinaryCodeDrawer: successfully loaded bit code data.")
    
    minStripeWidthCodeBitArrays = [[Bool]]()
    minStripeWidthCodeBitArrays?.reserveCapacity(codeCount)
    
    var dataIndex = 0;
    for _ in 0..<codeCount {
        var codeArray = [Bool]()
        codeArray.reserveCapacity(codeLength)
        
        for _ in 0..<codeLength {
            let codeBool = (codeData[dataIndex] == 0xFF)
            codeArray.append(codeBool)
            
            dataIndex += 1
        }
        minStripeWidthCodeBitArrays!.append(codeArray)
    }
}

var minSW_posToCode: [UInt32]? = nil
var minSW_codeToPos: [UInt32]? = nil

func loadMinSWCodes(filepath: String, codeCount: Int = 10, codeLength: Int = 1024) throws {
    let fileURL = URL(fileURLWithPath: filepath)
    let codeData = try Data(contentsOf: fileURL)
    print("BinaryCodes: successfully loaded min strip width code data.")
    
    minSW_posToCode = codeData.withUnsafeBytes {
        [UInt32](UnsafeBufferPointer(start: $0, count: codeLength*4))
    }
    minSW_codeToPos = codeData.advanced(by: codeLength*4).withUnsafeBytes {
        [UInt32](UnsafeBufferPointer(start: $0, count: codeLength*4))
    }
}
