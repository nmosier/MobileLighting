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
    var drawHorizontally: Bool = false
    var drawInverted: Bool = false
    
    init(context: NSGraphicsContext, frame: CGRect) {
        self.context = context
        self.frame = frame
        self.width = UInt(frame.width)
        self.height = UInt(frame.height)
    }
    
    func drawCode(forBit bit: UInt, system: BinaryCodeSystem, horizontally: Bool? = nil, inverted: Bool? = nil, positionLimit: UInt? = nil) {
        NSGraphicsContext.setCurrent(self.context)
        let context = self.context.cgContext
        
        let horizontally = horizontally ?? self.drawHorizontally
        let inverted = inverted ?? self.drawInverted       // temporarily use this configuration; does not change instance's settings
        
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
        
        // create raw buffer
        let bufferLength = width*height*4       // 4 bytes for each pixel: 0-R, 1-G, 2-B, 4-alpha
        
        struct Pixel {
            var r: UInt8
            var g: UInt8
            var b: UInt8
            var a: UInt8
        }
        
        let blackPixel = Pixel(r: 0, g: 0, b: 0, a: 255)
        let whitePixel = Pixel(r: 255, g: 255, b: 255, a: 255)
        
        // var data = Data(count: Int(bufferLength))
        
        
        //var data = Array<Pixel>(repeating: Pixel(r: 0, g: 0, b: 0, a: 255), count: Int(width*height))
        var data: Array<Pixel> = [Pixel]()
        data.reserveCapacity(Int(width*height))
        
        for y in 0..<height {
            for x in 0..<width {
                /*
                if x >= Int(nPositions) || y >= Int(nPositions) {
                    break
                } */
                
                //let index = Int(width)*y + x
                let barVal: Bool
                if (horizontally ? y : x) >= nPositions {
                    barVal = false
                } else {
                    barVal = bitArray[Int(horizontally ? y : x)]
                }
                data.append((barVal == inverted) ? blackPixel : whitePixel)    // (barVal == inverted) <=> barVal ^ inverted
            }
        }
        

        
        let provider = CGDataProvider(data: NSData(bytes: &data, length: data.count * 4))
        let colorspace: CGColorSpace = CGColorSpaceCreateDeviceRGB()
        let info: CGBitmapInfo = [CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)]
        let image = CGImage(width: Int(width), height: Int(height),
                            bitsPerComponent: 8, bitsPerPixel: 4*8, bytesPerRow: 4*Int(width), space: colorspace, bitmapInfo: info, provider: provider!,
                            decode: nil, shouldInterpolate: true, intent: CGColorRenderingIntent.defaultIntent)
        context.draw(image!, in: CGRect(x: 0, y: 0, width: Int(width), height: Int(height)))
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
