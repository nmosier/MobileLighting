//
//  GrayCode.swift
//  demo
//
//  Created by Nicholas Mosier on 6/20/17.
//  Copyright © 2017 Nicholas Mosier. All rights reserved.
//

import Foundation

enum BinaryCodeSystem: Int {
    case GrayCode, MinStripeWidthCode
}

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
var minSWcodeBitDisplayArrays: [[Bool]]?   // contains minstripewidth code bit arrays from minsSWcode.dat

// for displaying purposes only
func loadMinStripeWidthCodesForDisplay(filepath: String = "/Users/nicholas/OneDrive - Middlebury College/Summer Research 2017/demo-mobile-scene-capture/minSW.dat", bitCount: Int = 10) throws {
    try loadMinSWCodesConversionArrays(filepath: filepath)
    
    minSWcodeBitDisplayArrays = [[Bool]]()
    minSWcodeBitDisplayArrays!.reserveCapacity(bitCount)
    
    for bit in 0..<bitCount {
        var codeArray = [Bool]()
        codeArray.reserveCapacity(Int(minSW_ncodes!))
        for i in 0..<Int(minSW_ncodes!) {
            let codeBool = (minSW_posToCode![i] & (1<<UInt32(bit)) != 0)
            codeArray.append(codeBool)
        }
        minSWcodeBitDisplayArrays!.append(codeArray)
    }
}
    
func loadMinStripeWidthCodes_OLD(filepath: String = "/Users/nicholas/OneDrive - Middlebury College/Summer Research 2017/demo-mobile-scene-capture/demo_mac/minStripeWidthCodes.dat", codeCount: Int = 10, codeLength: Int = 1024) throws {
    
    let fileURL = URL(fileURLWithPath: filepath)
    let codeData = try Data(contentsOf: fileURL)
    
    print("BinaryCodeDrawer: successfully loaded bit code data.")
    
    minSWcodeBitDisplayArrays = [[Bool]]()
    minSWcodeBitDisplayArrays?.reserveCapacity(codeCount)
    
    var dataIndex = 0;
    for _ in 0..<codeCount {
        var codeArray = [Bool]()
        codeArray.reserveCapacity(codeLength)
        
        for _ in 0..<codeLength {
            let codeBool = (codeData[dataIndex] == 0xFF)
            codeArray.append(codeBool)
            
            dataIndex += 1
        }
        minSWcodeBitDisplayArrays!.append(codeArray)
    }
    
    // TEST: first code?
    // take 1st bool val of each subarray of code bit arrays
    var res: UInt32 = 0
    var res2: UInt32 = 0
    for i in 0..<minSWcodeBitDisplayArrays!.count {
        if minSWcodeBitDisplayArrays![i][1023] {
            res |= UInt32(1<<i)
            res2 |= UInt32(1<<(10-i))
        }
    }
    print ("Binary Codes: TEST — first code either \(res) or \(res2)")
}

var minSW_ncodes: UInt32?
var minSW_posToCode: [UInt32]? = nil
var minSW_codeToPos: [UInt32]? = nil

func loadMinSWCodesConversionArrays(filepath: String) throws {
    let fileURL = URL(fileURLWithPath: filepath)
    let codeData = try Data(contentsOf: fileURL)
    print("BinaryCodes: successfully loaded min strip width code data.")
    
    minSW_ncodes = codeData.withUnsafeBytes {
        UnsafePointer<UInt32>($0).pointee
    }
    
    guard minSW_ncodes == 1024 else {
        fatalError("BinaryCodes: fatal error — read # of min sw codes incorrectly.")
    }
    
    minSW_posToCode = codeData.advanced(by: 4).withUnsafeBytes {
        [UInt32](UnsafeBufferPointer(start: $0, count: Int(minSW_ncodes!)*4))
    }
    minSW_codeToPos = codeData.advanced(by: 4 + Int(minSW_ncodes!)*4).withUnsafeBytes {
        [UInt32](UnsafeBufferPointer(start: $0, count: Int(minSW_ncodes!)*4))
    }
}
