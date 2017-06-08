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

struct Pixel {
    var r: UInt8
    var g: UInt8
    var b: UInt8
    var a: UInt8
}
let blackPixel = Pixel(r: 0, g: 0, b: 0, a: 255)
let whitePixel = Pixel(r: 255, g: 255, b: 255, a: 255)

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
    
    static func getBitmap(forBit bit: UInt, system: BinaryCodeSystem, width: UInt, height: UInt, horizontally: Bool = false, inverted: Bool = false, positionLimit: UInt? = nil) -> CGImage {
        var nPositions = UInt(horizontally ? height: width)   // nPositions = # of diff. gray codes
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
                }
            }
            guard Int(bit) < BinaryCodeDrawer.minStripeWidthCodeBitArrays!.count else {
                fatalError("BinaryCodeDrawer: ERROR — specified bit for code too large.")
            }
            let fullBitArray = BinaryCodeDrawer.minStripeWidthCodeBitArrays![Int(bit)]
            bitArray = Array<Bool>(fullBitArray.prefix(Int(horizontally ? height : width)))
            guard Int(nPositions) <= bitArray.count else {
                fatalError("BinaryCodeDrawer: ERROR — cannot display min stripe width code, number of stripes too large.")
            }
            break
        }
        
        var bitmap: Array<Pixel> = Array<Pixel>(repeating: blackPixel, count: Int(width*height))
        
        for y in 0..<height {
            for x in 0..<width {
                let index = Int(width*y + x)
                let barVal: Bool
                if (horizontally ? y : x) >= nPositions {
                    barVal = false
                } else {
                    barVal = bitArray[Int(horizontally ? y : x)]
                }
                bitmap[index] = (barVal == inverted) ? blackPixel : whitePixel   // (barVal == inverted) <=> barVal ^ inverted
            }
        }
        
        print("A1: finished generating bitmap - \(timestampToString(date: Date()))")
        
        let provider = CGDataProvider(data: NSData(bytes: &bitmap, length: bitmap.count * 4))
        let colorspace: CGColorSpace = CGColorSpaceCreateDeviceRGB()
        let info: CGBitmapInfo = [CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)]
        let image = CGImage(width: Int(width), height: Int(height),
                            bitsPerComponent: 8, bitsPerPixel: 4*8, bytesPerRow: 4*Int(width), space: colorspace, bitmapInfo: info, provider: provider!,
                            decode: nil, shouldInterpolate: true, intent: CGColorRenderingIntent.defaultIntent)
        return image!
    }
    
    let context: NSGraphicsContext
    let frame: CGRect
    let width: UInt
    let height: UInt
    var drawHorizontally: Bool = false
    var drawInverted: Bool = false
    
    var bitmaps: [CGImage] = [CGImage]()
    var bitmaps_inverted: [CGImage] = [CGImage]()
    var bitmap: Array<Pixel>
    
    let blackHorizontalBar: Array<Pixel>
    let whiteHorizontalBar: Array<Pixel>
    init(context: NSGraphicsContext, frame: CGRect) {
        self.context = context
        self.frame = frame
        self.width = UInt(frame.width)
        self.height = UInt(frame.height)
        
        bitmap = Array<Pixel>(repeating: blackPixel, count: Int(width*height))
        blackHorizontalBar = Array<Pixel>(repeating: blackPixel, count: Int(width))
        whiteHorizontalBar = Array<Pixel>(repeating: whitePixel, count: Int(width))
    }
    
    func generateBitmaps(system: BinaryCodeSystem, horizontally: Bool = false) {
        let nBits: Int = Int(log2(Double(horizontally ? height : width)))
        
        for bit in 0..<nBits {
            bitmaps.append(BinaryCodeDrawer.getBitmap(forBit: UInt(bit), system: system, width: width, height: height))
        }
        
    }
    
    func drawCode(forBit bit: UInt, system: BinaryCodeSystem, horizontally: Bool? = nil, inverted: Bool? = nil, positionLimit: UInt? = nil) {
        print("A: starting to draw code - \(timestampToString(date: Date()))")
        
        NSGraphicsContext.setCurrent(self.context)
        let context = self.context.cgContext
        
        
        /*
        context.draw(bitmaps[Int(bit)], in: CGRect(x: 0, y: 0, width: Int(width), height: Int(height)))
        
        return
        */

        
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
        
        // var data = Data(count: Int(bufferLength))
        
        
        //var data = Array<Pixel>(repeating: Pixel(r: 0, g: 0, b: 0, a: 255), count: Int(width*height))
        
        print("A0: starting to go thru loop - \(timestampToString(date: Date()))")
        
        
        // bitmap array is already initialized to save time
        
        /*
        for y in 0..<height {
            for x in 0..<width {
                let index = Int(width*y + x)
                let barVal: Bool
                if (horizontally ? y : x) >= nPositions {
                    barVal = false
                } else {
                    barVal = bitArray[Int(horizontally ? y : x)]
                }
                bitmap[index] = (barVal == inverted) ? blackPixel : whitePixel   // (barVal == inverted) <=> barVal ^ inverted
            }
        } */
 
        
        // generate bars before hand
        
        var horizontalBar: Array<Pixel> = (inverted ? whiteHorizontalBar : blackHorizontalBar)
        let max: Int
        
        //var bitmap2 = Data(count: Int(width*height*4))
        //var bitmap2 = UnsafeMutablePointer<UInt8>(malloc(Int(width*height*4))!)
        var bitmap2 = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(width*height*4))
        
        if !horizontally {
            // vertically
            max = Int(nPositions)
            var barVal: Bool
            for index in 0..<max {
                barVal = bitArray[index]
                horizontalBar[index] = (barVal == inverted) ? blackPixel : whitePixel
            }
            let data = Data(bytes: &horizontalBar, count: Int(width*4))
            for row in 0..<Int(height) {
                data.copyBytes(to: bitmap2.advanced(by: row*Int(width)*4), count: Int(width)*4)
                //bitmap.replaceSubrange(row*Int(width)..<row*Int(width+1), with: horizontalBar)
            }
        } else {
            // horizontally
            max = Int(width)
            for row in 0..<Int(height) {
                let bar = (row < Int(nPositions)) ? ((bitArray[row] == inverted) ? blackHorizontalBar : whiteHorizontalBar) : (inverted ? whiteHorizontalBar : blackHorizontalBar)
                let data = Data(bytes: bar, count: Int(width*4))
                data.copyBytes(to: bitmap2.advanced(by: row*Int(width)*4), count: Int(width)*4)
                //bitmap.replaceSubrange(row*Int(width)..<row*Int(width+1), with:  (row < Int(nPositions)) ? ((bitArray[row] == inverted) ? blackHorizontalBar : whiteHorizontalBar) : (inverted ? whiteHorizontalBar : blackHorizontalBar)  )
            }
        }
        
        
        /*
        var index = 0
        let max = Int(height*width)
        while index < max {
            let (x, y) = (index % Int(width), index / Int(width))
            let barVal: Bool
            if (horizontally ? y : x) >= Int(nPositions) {
                barVal = false
            } else {
                barVal = bitArray[Int(horizontally ? y : x)]
            }
            bitmap[index] = (barVal == inverted) ? blackPixel : whitePixel
            
            index += 1
        }*/
 
        print("A1: finished generating bitmap - \(timestampToString(date: Date()))")
        let provider = CGDataProvider(data: NSData(bytes: bitmap2, length: bitmap.count * 4))
        let colorspace: CGColorSpace = CGColorSpaceCreateDeviceRGB()
        let info: CGBitmapInfo = [CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)]
        let image = CGImage(width: Int(width), height: Int(height),
                            bitsPerComponent: 8, bitsPerPixel: 4*8, bytesPerRow: 4*Int(width), space: colorspace, bitmapInfo: info, provider: provider!,
                            decode: nil, shouldInterpolate: true, intent: CGColorRenderingIntent.defaultIntent)
        context.draw(image!, in: CGRect(x: 0, y: 0, width: Int(width), height: Int(height)))
        
        print("B: finished drawing code - \(timestampToString(date: Date()))")
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
