//
//  Graycodes.swift
//  demo
//
//  Created by Nicholas Mosier on 6/6/17.
//  Copyright © 2017 Nicholas Mosier. All rights reserved.
//

import Foundation
import Cocoa
import CoreGraphics

enum BinaryCodeSystem {
    case GrayCode, MinStripeWidthCode
}

class BinaryCodeDrawer {
    // static properties
    static var minStripeWidthCodeBitArrays: [[Bool]]?   // contains minstripewidth code bit arrays from minsSWcode.dat
    
    // static utility functions
    static func loadMinStripeWidthCodes(filepath: String = "/Users/nicholas/OneDrive - Middlebury College/Summer Research 2017/demo-mobile-scene-capture/demo_mac/minStripeWidthCodes.dat", codeCount: Int = 10, codeLength: Int = 1024) throws {
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
    
    let context: NSGraphicsContext
    let frame: CGRect
    let width: UInt
    let height: UInt
    
    init(context: NSGraphicsContext, frame: CGRect) {
        self.context = context
        self.frame = frame
        self.width = UInt(frame.width)
        self.height = UInt(frame.height)
    }
    
    
    func drawCode(forBit bit: UInt, system: BinaryCodeSystem, horizontally: Bool = false, inverted: Bool = false, positionLimit: UInt? = nil) {
        NSGraphicsContext.setCurrent(self.context)
        let context = self.context.cgContext
        var nPositions = UInt(horizontally ? frame.size.height: frame.size.width)   // nPositions = # of diff. gray codes
        if positionLimit != nil && nPositions > positionLimit! {
            nPositions = positionLimit!
        }
        
        let bitArray: [Bool]
        switch system {
        case .GrayCode:
            bitArray = grayCodeArray(forBit: bit, size: nPositions)
            break
        case .MinStripeWidthCode:
            if BinaryCodeDrawer.minStripeWidthCodeBitArrays == nil {
                do {
                    try BinaryCodeDrawer.loadMinStripeWidthCodes()
                } catch {
                    print("BinaryCodeDrawer: unable to load min strip width codes from data file.")
                    return
                }
            }
            guard Int(bit) < BinaryCodeDrawer.minStripeWidthCodeBitArrays!.count else {
                print("BinaryCodeDrawer: ERROR — specified bit for code too large.")
                return
            }
            let fullBitArray = BinaryCodeDrawer.minStripeWidthCodeBitArrays![Int(bit)]
            bitArray = Array<Bool>(fullBitArray.prefix(Int(horizontally ? height : width)))
            guard Int(nPositions) <= bitArray.count else {
                print("BinaryCodeDrawer: ERROR — cannot display min stripe width code, number of stripes too large.")
                return
            }
            break
        }
        
        for i in 0..<Int(nPositions) {
            let bar = bitArray[i]
            let initial = horizontally ? CGPoint(x: 0, y: i) : CGPoint(x: i, y: 0)
            let terminal = horizontally ? CGPoint(x: frame.size.width, y: CGFloat(i)) : CGPoint(x: CGFloat(i), y: frame.size.height)
            
            context.setLineWidth(1)
            context.setStrokeColor( (bar != inverted) ? CGColor.black : CGColor.white)  // != same effect as XOR
            
            context.move(to: initial)
            context.addLine(to: terminal)
            context.strokePath()
        }
    }
    
    
}

func grayCodeArray(forBit bit: UInt, size: UInt) -> [Bool] {
    var array = [Bool]()
    array.reserveCapacity(Int(size))
    
    for i in 0..<size {
        array.append(getBit(grayCode(of: UInt(i)), bit: bit))
    }
    return array
}

func grayCode(of pos: UInt) -> UInt {
    return pos ^ (pos >> 1)
}

func getBit(_ n: UInt, bit: UInt) -> Bool {
    return (n & (1 << bit)) != 0
}
