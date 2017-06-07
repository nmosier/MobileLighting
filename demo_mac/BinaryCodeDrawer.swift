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
        /*guard let data = malloc(Int(bufferLength) * MemoryLayout<UInt8>.size) else {
            print("BinaryCodeDrawer: ERROR — unable to allocate buffer for drawing binary code.")
            return
        }*/
        
        struct Pixel {
            var r: UInt8
            var g: UInt8
            var b: UInt8
            var a: UInt8 = 255
        }
        
        // var data = Data(count: Int(bufferLength))
        var data = Array<Pixel>(repeating: Pixel(r: 0, g: 0, b: 0, a: 255), count: Int(width*height))
        //data.reserveCapacity(Int(width*height))
        
        Swift.print("WIDTH: \(width), HEIGHT: \(height)")
        
        for y in 0..<Int(height) {
            for x in 0..<Int(width) {
                /*
                if x >= Int(nPositions) || y >= Int(nPositions) {
                    break
                } */
                
                let index = Int(width)*y + x
                
                
                
                let barVal = bitArray[horizontally ? y : x]
                
                let val: UInt8
                if barVal {
                    // draw white
                    val = 255
                    //data[index] = 255
                    //data[index+1] = 255
                    //data[index+2] = 255
                } else {
                    // draw black
                    val = 0
                }
                //data.storeBytes(of: val, toByteOffset: index, as: type(of: val))
                //data.storeBytes(of: val, toByteOffset: index+1, as: type(of: val))
                //data.storeBytes(of: val, toByteOffset: index+2, as: type(of: val))
                //data.storeBytes(of: UInt8(255), toByteOffset: index+3, as: type(of: UInt8()))
                data[index].r = val
                data[index].g = val
                data[index].b = val
                //data[index+3] = UInt8(255)
            }
        }
        
        for i in 0..<Int(nPositions) {
            let bar = bitArray[i]
            let initial = horizontally ? CGPoint(x: 0, y: i) : CGPoint(x: i, y: 0)
            let terminal = horizontally ? CGPoint(x: frame.size.width, y: CGFloat(i)) : CGPoint(x: CGFloat(i), y: frame.size.height)
            
            context.setLineWidth(1)
            context.setStrokeColor( (bar != inverted) ? CGColor.black : CGColor.white)  // != same effect as XOR
            
            context.move(to: initial)
            context.addLine(to: terminal)
            context.drawPath(using: .eoFillStroke)
            //context.strokePath()
        }
        
        let releaseMaskImagePixelData: CGDataProviderReleaseDataCallback = { (info: UnsafeMutableRawPointer?, data: UnsafeRawPointer, size: Int) -> () in
            // https://developer.apple.com/reference/coregraphics/cgdataproviderreleasedatacallback
            // N.B. 'CGDataProviderRelease' is unavailable: Core Foundation objects are automatically memory managed
            return
        }
        var tempdata = NSData(bytes: &data, length: data.count * 4)
        //let provider = CGDataProvider(dataInfo: nil, data: &tempdata, size: Int(bufferLength), releaseData: releaseMaskImagePixelData)
        
        let provider = CGDataProvider(data: tempdata)
        
        let colorspace: CGColorSpace = CGColorSpaceCreateDeviceRGB()
        let info: CGBitmapInfo = [CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)]
        let image = CGImage(width: Int(width), height: Int(height),
                            bitsPerComponent: 8, bitsPerPixel: 4*8, bytesPerRow: 4*Int(width), space: colorspace, bitmapInfo: info, provider: provider!,
                            decode: nil, shouldInterpolate: true, intent: CGColorRenderingIntent.defaultIntent)
        context.draw(image!, in: CGRect(x: 0, y: 0, width: Int(width), height: Int(height)))
        // release?
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
