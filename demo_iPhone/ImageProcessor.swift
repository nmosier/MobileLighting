//
//  ImageProcessor.swift
//  demo
//
//  Created by Nicholas Mosier on 6/9/17.
//  Copyright © 2017 Nicholas Mosier. All rights reserved.
//

import Foundation
import AVFoundation
import CoreImage

let context = CIContext(options: [kCIContextWorkingColorSpace : NSNull()])

struct Pixel {
    var r: UInt8
    var g: UInt8
    var b: UInt8
    var a: UInt8
}

func processPixelBufferPair2(normal: CVPixelBuffer, inverted: CVPixelBuffer) -> CVPixelBuffer {
    let lockFlags = CVPixelBufferLockFlags(rawValue: 0) // read & write
    CVPixelBufferLockBaseAddress(normal, lockFlags)
    CVPixelBufferLockBaseAddress(inverted, lockFlags)
    
    var imNormal: CIImage = CIImage(cvPixelBuffer: normal)
    var imInverted: CIImage = CIImage(cvPixelBuffer: inverted)
    
    // apply gray monochrome filter to colors
    let colorMonochromeFilter = CIFilter(name: "CIColorMonochrome")!
    colorMonochromeFilter.setValue(CIColor.gray(), forKey: kCIInputColorKey)
    
    colorMonochromeFilter.setValue(imNormal, forKey: kCIInputImageKey)
    imNormal = colorMonochromeFilter.outputImage!
    colorMonochromeFilter.setValue(imInverted, forKey: kCIInputImageKey)
    imInverted = colorMonochromeFilter.outputImage!
    
    // invert colors for image of inverted pattern
    let colorInvertFilter = CIFilter(name: "CIColorInvert")!
    colorInvertFilter.setValue(imInverted, forKey: kCIInputImageKey)
    imInverted = colorInvertFilter.outputImage!
    
    // scale exposures by 0.5
    var exposureAdjustFilter = CIFilter(name: "CIExposureAdjust")!
    exposureAdjustFilter.setValue(-1.0, forKey: kCIInputEVKey)
    exposureAdjustFilter.setValue(imNormal, forKey: kCIInputImageKey)
    imNormal = exposureAdjustFilter.outputImage!
    
    exposureAdjustFilter.setValue(imInverted, forKey: kCIInputImageKey)
    imInverted = exposureAdjustFilter.outputImage!
    
    // add imNormal and imInverted together
    let additionCompositingFilter = CIFilter(name: "CIAdditionCompositing")!
    additionCompositingFilter.setValue(imNormal, forKey: kCIInputImageKey)
    additionCompositingFilter.setValue(imInverted, forKey: kCIInputBackgroundImageKey)
    
    let resultingImage = additionCompositingFilter.outputImage!
    context.render(resultingImage, to: normal)
    return normal
}

func processPixelBufferPair(normal: CVPixelBuffer, inverted: CVPixelBuffer) -> CVPixelBuffer {
    return processPixelBufferPair2(normal: normal, inverted: inverted)
    
    ///
    ///
    ///
    
    print("Image Processor: width of buffer \(CVPixelBufferGetWidth(normal)), height of buffer \(CVPixelBufferGetHeight(normal))")
    
    print("ImageProcessor: processing pixel buffer pair")
    
    let lockFlags = CVPixelBufferLockFlags(rawValue: 0) // read & write
    CVPixelBufferLockBaseAddress(normal, lockFlags)
    CVPixelBufferLockBaseAddress(inverted, lockFlags)
    
    guard normal.width == inverted.width, normal.height == inverted.height, normal.bytesPerRow == inverted.bytesPerRow, normal.pixelFormatType == inverted.pixelFormatType else {
        print("ImageProcessor: error – pixel buffers not of same type.")
        return normal
    }
    
    let rowCount = normal.height
    let colCount = normal.width
    let bytesPerRow = normal.bytesPerRow
    
    print("ImageProcessor: bytes per row \(bytesPerRow), cols \(colCount)")
    
    for row in 0..<rowCount {
        let offset = bytesPerRow * row
        let rowPtr_normal = normal.baseAddress!.advanced(by: offset)
        let rowPtr_inverted = inverted.baseAddress!.advanced(by: offset)
        
        let rowData_normal = Data(bytes: rowPtr_normal, count: bytesPerRow)
        let rowData_inverted = Data(bytes: rowPtr_inverted, count: bytesPerRow)
        var rowData_intensity = Data(repeating: 255, count: bytesPerRow)
        
        for col in 0..<colCount {
            var intensityDiff: Int
            intensityDiff = ((Int(rowData_normal[col*4]) + Int(rowData_normal[col*4+1]) + Int(rowData_normal[col*4+2])) -
                Int(rowData_inverted[col*4]) - Int(rowData_inverted[col*4+1]) - Int(rowData_inverted[col*4+2])) / 3
            var value: UInt8
            intensityDiff += 128
            intensityDiff = (intensityDiff > 255) ? 255 : intensityDiff
            intensityDiff = (intensityDiff < 0) ? 0 : intensityDiff
            value = UInt8(intensityDiff)
            
            rowData_intensity[col*4] = value
            rowData_intensity[col*4+1] = value
            rowData_intensity[col*4+2] = value
            rowData_intensity[col*4+3] = 255    // A
        }
        
        
        //rowData_intensity.copyBytes(to: rowPtr_normal, count: bytesPerRow)
        //rowPtr_normal.copyBytes(from: rowData_intensity, count: bytesPerRow)
        //rowPtr_normal.storeBytes(of: rowData_intensity, as: Data.self)
        let temp_nsData = rowData_intensity as NSData
        rowPtr_normal.copyBytes(from: temp_nsData.bytes, count: bytesPerRow)
        
    }
    
    CVPixelBufferUnlockBaseAddress(normal, lockFlags)
    CVPixelBufferUnlockBaseAddress(inverted, lockFlags)
    
    return normal
}

func combineIntensityBuffers(_ buffers: [CVPixelBuffer]) -> CVPixelBuffer {
    // NEEDS TO BE IMPLEMENTED
    
    //placeholder
    return buffers.first!
}

extension CVPixelBuffer {
    var baseAddress: UnsafeMutableRawPointer? {
        get {
            return CVPixelBufferGetBaseAddress(self)
        }
    }
    var width: Int {
        get {
            return CVPixelBufferGetWidth(self)
        }
    }
    var height: Int {
        get {
            return CVPixelBufferGetHeight(self)
        }
    }
    var pixelFormatType: OSType {
        get {
            return CVPixelBufferGetPixelFormatType(self)
        }
    }
    var bytesPerRow: Int {
        get {
            return CVPixelBufferGetBytesPerRow(self)
        }
    }
    
    func deepcopy() -> CVPixelBuffer? {
        let width = CVPixelBufferGetWidth(self)
        let height = CVPixelBufferGetHeight(self)
        let format = CVPixelBufferGetPixelFormatType(self)
        var pixelBufferCopyOptional:CVPixelBuffer?
        CVPixelBufferCreate(nil, width, height, format, nil, &pixelBufferCopyOptional)
        if let pixelBufferCopy = pixelBufferCopyOptional {
            CVPixelBufferLockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0x00000001)) // kCVPixelBufferLock_ReadOnly
            CVPixelBufferLockBaseAddress(pixelBufferCopy, CVPixelBufferLockFlags(rawValue: 0))
            let baseAddress = CVPixelBufferGetBaseAddress(self)
            let dataSize = CVPixelBufferGetDataSize(self)
            print("dataSize: \(dataSize)")
            let target = CVPixelBufferGetBaseAddress(pixelBufferCopy)
            memcpy(target, baseAddress, dataSize)
            CVPixelBufferUnlockBaseAddress(pixelBufferCopy, CVPixelBufferLockFlags(rawValue: 0))
            CVPixelBufferUnlockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0x00000001))
        }
        return pixelBufferCopyOptional
    }
}
