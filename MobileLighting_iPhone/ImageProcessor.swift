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
import Photos

// used by custom threshold filter as default when no input threshold specified
var thresholdDefault: Float = 0.06
var binaryCodeDirection: Bool?
var brightnessChangeDirection: Double?

let context = CIContext(options: [kCIContextWorkingColorSpace : NSNull()])

func processCodeImages(normal pixelBuffers_normal: [CVPixelBuffer], inverted pixelBuffers_inverted: [CVPixelBuffer], for bit: Int) {
    guard pixelBuffers_normal.count == pixelBuffers_inverted.count else {
        print("CameraController: ERROR - mismatch in normal-inverted bracket pair sample buffer count.")
        let packet = PhotoDataPacket.error()
        photoSender.sendPacket(packet)
        return
    }
    
    var intensityBuffers = [CVPixelBuffer]()
    for i in 0..<pixelBuffers_normal.count {
        let normalBuffer = pixelBuffers_normal[i]
        let invertedBuffer = pixelBuffers_inverted[i]
        
        let intensityBuffer = intensityDifference(normal: normalBuffer, inverted: invertedBuffer)
        intensityBuffers.append(intensityBuffer)
    }
//    pixelBuffers_normal.removeAll()
//    pixelBuffers_inverted.removeAll()
    
    var combinedIntensityBuffer = combineIntensities(intensityBuffers, shouldThreshold: true)
    intensityBuffers.removeAll()
    
    // rectify images if option set
    #if RECTIFY_ON_IPHONE
    combinedIntensityBuffer = rectifyPixelBuffer(combinedIntensityBuffer, camera: stereoPosition)
    #endif
    // get prominent stripe direction
    // if this is for the first structured lighting image
    if (bit == 0) {
        brightnessChangeDirection = brightnessChange(combinedIntensityBuffer)
        sceneMetadata.angle = brightnessChangeDirection! - Double.pi/2
    }
    
    let threshBuffer: CVPixelBuffer = threshold(img: combinedIntensityBuffer, thresh: threshold_val, angle: brightnessChangeDirection ?? 0.0 )
    // decode threshold image for current bit using decoder
    decoder!.decode(threshBuffer, forBit: bit)
    
    
    //MARK: send prethreshold images?
    if (shouldSendThreshImgs) {
        let prethreshData: Data
        let threshData: Data
        
        let prethreshPgm = PGMFile(buffer: combinedIntensityBuffer)
        prethreshData = prethreshPgm.getPGMData()
        let threshPgm = PGMFile(buffer: threshBuffer)
        threshData = threshPgm.getPGMData()
        
        let prethresh_packet = PhotoDataPacket(photoData: prethreshData, bracketedPhotoID: 0)
        photoSender.sendPacket(prethresh_packet)
        let thresh_packet = PhotoDataPacket(photoData: threshData, bracketedPhotoID: 0)
        photoSender.sendPacket(thresh_packet)
    } else {
        let packet = PhotoDataPacket(photoData: Data(), statusUpdate: .None)
        photoSender.sendPacket(packet)
    }
}

func intensityDifference(normal: CVPixelBuffer, inverted: CVPixelBuffer) -> CVPixelBuffer {
    // test intensity difference filter
    let imageN = CIImage(cvPixelBuffer: normal)
    let imageI = CIImage(cvPixelBuffer: inverted)
    let filter = IntensityDifferenceFilter()
    filter.setValue(imageN, forKey: kCIInputImageKey)
    filter.setValue(imageI, forKey: kCIInputBackgroundImageKey)
    let imageDiff = filter.outputImage!
    
    let grayscaleFilter = GrayscaleFilter()
    grayscaleFilter.setValue(imageDiff, forKey: kCIInputImageKey)
    grayscaleFilter.setValue([1.0/3, 1.0/3, 1.0/3] as [Float], forKey: GrayscaleFilter.kCIRGBWeightsKey)
    let imageGray = grayscaleFilter.outputImage!
    context.render(imageGray, to: normal)
    return normal
}

func combineIntensities(_ buffers: [CVPixelBuffer], shouldThreshold: Bool) -> CVPixelBuffer {
    guard buffers.count > 0 else {
        fatalError("ImageProcessor: fatal error — number of buffers supplied must be >= 1.")
    }
    if buffers.count == 1 {
        return buffers[0]
    }
    var inputImages: [CIImage] = buffers.map { (buffer: CVPixelBuffer) -> CIImage in
        return CIImage(cvPixelBuffer: buffer)
    }
    let extremeIntensitiesFilter = ExtremeIntensitiesFilter()
    extremeIntensitiesFilter.setValue(inputImages[0], forKey: kCIInputImageKey)
    var resultImage: CIImage = CIImage()
    for i in 1..<inputImages.count {
        extremeIntensitiesFilter.setValue(inputImages[i], forKey: kCIInputBackgroundImageKey)
        resultImage = extremeIntensitiesFilter.outputImage!
    }
    // use buffers[0] as "accumulator" for extremes
    context.render(resultImage, to: buffers[0])
    return buffers[0]
}

#if RECTIFY_ON_IPHONE
func rectifyPixelBuffer(_ buffer: CVPixelBuffer, camera: Int) -> CVPixelBuffer {
    var intrinsics = (Bundle.main.bundlePath + "/intrinsics.yml").cString(using: .ascii)!
    var extrinsics = (Bundle.main.bundlePath + "/extrinsics.yml").cString(using: .ascii)!
    computemaps(Int32(buffer.height), Int32(buffer.width), &intrinsics, &extrinsics)    // transpose width & height because the pixelbuffer is rotated (i.e. 1920 x 1080), but camera matrices expecting 1080x1920 image
    
    let camera = Int32(camera)
    let ciimage = CIImage(cvPixelBuffer: buffer)
    let tmpContext = CIContext(options: nil)
    let rect = CGRect(x: 0, y: 0, width: buffer.width, height: buffer.height)
    let cgim = tmpContext.createCGImage(ciimage, from: rect)
    let uiim = UIImage(cgImage: cgim!)
    
    let uiim2 = rectifyCodes(camera, uiim)!
    
    UIImageWriteToSavedPhotosAlbum(uiim2, nil, nil, nil)
    print("uiwidth=\(uiim2.size.width),uiheight=\(uiim2.size.height)")
    var outbuffer: CVPixelBuffer? = nil
    CVPixelBufferCreate(kCFAllocatorDefault, Int(uiim2.size.width), Int(uiim2.size.height), kCVPixelFormatType_32BGRA, nil, &outbuffer)
    print("width=\(CVPixelBufferGetWidth(outbuffer!)),height=\(CVPixelBufferGetHeight(outbuffer!))")
    CVPixelBufferLockBaseAddress(outbuffer!, CVPixelBufferLockFlags(rawValue:0))
    let colorspace = CGColorSpaceCreateDeviceRGB()
    
    let bitmapContext = CGContext(data: CVPixelBufferGetBaseAddress(outbuffer!), width: Int(uiim2.size.width), height: Int(uiim2.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(outbuffer!), space: colorspace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    bitmapContext.draw(uiim2.cgImage!, in: CGRect(x: 0, y: 0, width: uiim2.size.width, height: uiim2.size.height))
    print("width=\(CVPixelBufferGetWidth(outbuffer!)),height=\(CVPixelBufferGetHeight(outbuffer!))")
    CVPixelBufferUnlockBaseAddress(outbuffer!, CVPixelBufferLockFlags(rawValue:0))
    return outbuffer!
}
#endif

// implements zero-crossing thresholding algorithm
//  using pixel loop
func threshold(img: CVPixelBuffer, thresh: Double, angle: Double) -> CVPixelBuffer {
    // kCVPixelFormatType_32BGRA
    // 32 bits per pixel
    let out_img: CVPixelBuffer = img.deepcopy()!
    guard img.width == out_img.width && img.height == out_img.height else {
        fatalError("zc-threshold: cannot write thresheld image to CVPixelBuffer of mismatched dimensions")
    }
    
    let bytesPerRow = CVPixelBufferGetBytesPerRow(img)
    let w = img.width
    let h = img.height
    let dx = Int(round(cos(angle)))
    let dy = Int(round(sin(angle)))
    
    print("(dx,dy)=(\(dx),\(dy))")
    print("thresh - bytes per row \(bytesPerRow), width \(CVPixelBufferGetWidth(img))")
    
    let lockFlags = CVPixelBufferLockFlags(rawValue: 0) // read & write
    CVPixelBufferLockBaseAddress(img, lockFlags)
    CVPixelBufferLockBaseAddress(out_img, lockFlags)
    
    
    let img_ptr_raw: UnsafeMutableRawPointer = CVPixelBufferGetBaseAddress(img)!
    let img_ptr = img_ptr_raw.bindMemory(to: UInt8.self, capacity: bytesPerRow*h)
    let out_ptr_raw: UnsafeMutableRawPointer = CVPixelBufferGetBaseAddress(out_img)!
    let out_ptr = out_ptr_raw.bindMemory(to: UInt8.self, capacity: bytesPerRow*h)
    for y in 0..<h {
        for x in 0..<w {
            let val: Double = Double(img_ptr[y*bytesPerRow + 4*x]) / 255.0
            var out: UInt8
            if (min( x+dx, x-dx) < 0 || max(x+dx, x-dx) >= w || min(y+dy, y-dy) < 0 || max(y+dy, y-dy) >= h) {
                if (val - 0.5 >= thresh) {
                    out = 255
                } else if (0.5 - val >= thresh) {
                    out = 0
                } else {
                    out = 128
                }
            } else {
                let val_l = Double(img_ptr[bytesPerRow*(y+dy) + 4*(x+dx)]) / 255.0
                let val_r = Double(img_ptr[bytesPerRow*(y-dy) + 4*(x-dx)]) / 255.0
                if (sign(val_l-0.5) == sign(val_r-0.5) || min( abs(val_l - 0.5), abs(val_r - 0.5) ) < thresh) {
                    if (val - 0.5 >= thresh) {
                        out = 255
                    } else if (0.5 - val >= thresh) {
                        out = 0
                    } else {
                        out = 128
                    }
                    
                } else {
                    if val == 0.5 {
                        out = 128
                    } else if val > 0.5 {
                        out = 255
                    } else {
                        out = 0
                    }
                }
            }
            
            out_ptr[bytesPerRow*y + 4*x] = out
            out_ptr[bytesPerRow*y + 4*x + 1] = out
            out_ptr[bytesPerRow*y + 4*x + 2] = out
            out_ptr[bytesPerRow*y + 4*x + 3] = 255
        }
    }
    
    CVPixelBufferUnlockBaseAddress(img, lockFlags)
    CVPixelBufferUnlockBaseAddress(out_img, lockFlags)
    return out_img
}

func brightnessChange(_ srcBuffer: CVPixelBuffer) -> Double {
    let w = srcBuffer.width
    let h = srcBuffer.height
    let bytesPerRow = srcBuffer.bytesPerRow
    
    CVPixelBufferLockBaseAddress(srcBuffer, lockFlags)
    let raw_ptr: UnsafeMutableRawPointer = CVPixelBufferGetBaseAddress(srcBuffer)!
    let ptr = raw_ptr.bindMemory(to: UInt8.self, capacity: bytesPerRow*h)
    
    var sum_0 = 0, sum_pi4 = 0, sum_pi2 = 0, sum_3pi4 = 0
    var avg_0: Double, avg_pi4: Double, avg_pi2: Double, avg_3pi4: Double
    
    // find avg brightness change for right dir
    for y in 0..<h {
        for x in 0..<(w-1) {
            let val_l: Int = Int(ptr[bytesPerRow*y + 4*x])
            let val_r: Int = Int(ptr[bytesPerRow*y + 4*x + 4])
            sum_0 += abs(val_l - val_r)
        }
    }
    avg_0 = Double(sum_0) / Double(h*(w-1))
    
    // down
    for x in 0..<w {
        for y in 0..<(h-1) {
            let val_l: Int = Int(ptr[bytesPerRow*y + 4*x])
            let val_r: Int = Int(ptr[bytesPerRow*(y+1) + 4*x])
            sum_pi2 += abs(val_l - val_r)
        }
    }
    avg_pi2 = Double(sum_pi2) / Double(w*(h-1))
    
    // down & right
    for y in 0..<(h-1) {
        for x in 0..<(w-1) {
            let val_l: Int = Int(ptr[bytesPerRow*y + 4*x])
            let val_r: Int = Int(ptr[bytesPerRow*(y+1) + 4*(x+1)])
            sum_pi4 += abs(val_l - val_r)
        }
    }
    avg_pi4 = Double(sum_pi4) / Double((w-1)*(h-1))
    
    // down & left
    for y in 0..<(h-1) {
        for x in 0..<(w-1) {
            let val_l: Int = Int(ptr[bytesPerRow*y + 4*(x+1)])
            let val_r: Int = Int(ptr[bytesPerRow*(y+1) + 4*x])
            sum_3pi4 += abs(val_l - val_r)
        }
    }
    avg_3pi4 = Double(sum_3pi4) / Double((w-1)*(h-1))
    
    let ratio_xy = max(avg_0 / avg_pi2, avg_pi2 / avg_0)
    let ratio_diag = max(avg_pi4 / avg_3pi4, avg_3pi4 / avg_pi4)
    
    print("avg_0 = \(avg_0), avg_pi4=\(avg_pi4), avg_pi2=\(avg_pi2), avg_3pi4=\(avg_3pi4)")
    
    let angle: Double
    if (ratio_xy >= ratio_diag) {
        if (avg_0 >= avg_pi2) {
            angle = 0.0
        } else {
            angle = Double.pi/2
        }
    } else {
        if (avg_pi4 >= avg_3pi4) {
            angle = Double.pi/4
        } else {
            angle = 3*Double.pi/4
        }
    }
    CVPixelBufferUnlockBaseAddress(srcBuffer, lockFlags)
    return angle
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

//MARK: Decoder class
class Decoder {
    // properties
    let binaryCodeSystem: BinaryCodeSystem
    var valueArray: [UInt32] // use Int32 so masking works properly
    var unknownArray: [UInt32]
    let width: Int
    let height: Int
    
    init(width: Int, height: Int, binaryCodeSystem: BinaryCodeSystem) {
        self.width = width
        self.height = height
        self.valueArray = Array<UInt32>(repeating: 0, count: width*height)
        self.unknownArray = Array<UInt32>(repeating: 0, count: width*height)
        
        self.binaryCodeSystem = binaryCodeSystem
        
        if binaryCodeSystem == .MinStripeWidthCode && minSW_codeToPos == nil {
            do {
                let filepath = Bundle.main.resourcePath! + "/minSW.dat" 
                try loadMinSWCodesConversionArrays(filepath: filepath)
            } catch {
                print("Decoder: failed to load minSWcodes for processing.")
            }
        }
    }
    
    func decode(_ thresholdBuffer: CVPixelBuffer, forBit bit: Int) {
        guard width == thresholdBuffer.width &&
            height == thresholdBuffer.height else {
                print("ImageProcessor Decoder: ERROR — mismatch in dimensions of provided threshold image with existing decoder pixel array.")
                fatalError()
        }
        
        CVPixelBufferLockBaseAddress(thresholdBuffer, CVPixelBufferLockFlags(rawValue: 0))
        let threshPtr = CVPixelBufferGetBaseAddress(thresholdBuffer)!.bindMemory(to: UInt8.self, capacity: width*height*4)
        let stride = CVPixelBufferGetBytesPerRow(thresholdBuffer)
        for y in 0..<height {
            for x in 0..<width {
                let offset = y*stride + 4*x
                let index = y*width + x
                let threshval = threshPtr[offset]
                if threshval == 128 {
                    unknownArray[index] |= UInt32(1 << bit)
                } else if threshval == 255 {
                    valueArray[index] |= UInt32(1 << bit)
                } else if threshval != 0 {
                    print ("ImageProcessor — WARNING, VALUE \(threshval) UNEXPECTED")
                }
            }
        }
        /*
        for i in 0..<width*height {
            let threshval = threshPtr.pointee
            if threshval == 128 {
                unknownArray[i] |= UInt32(1 << bit)
            } else if threshval == 255 {
                valueArray[i] |= UInt32(1 << bit)
            } else if threshval != 0 {
                print ("ImageProcessor — WARNING, VALUE \(threshval) UNEXPECTED")
            }
            
            threshPtr = threshPtr.advanced(by: 4)
        }
        */
        CVPixelBufferUnlockBaseAddress(thresholdBuffer, CVPixelBufferLockFlags(rawValue: 0))
    }
    
    // ROTATED
    func getPFMData() -> Data {
        let dimensionDict: [AVCaptureVideoOrientation : (Int,Int) -> (Int, Int)] = [
            .portrait : { return ($1,$0)  }, // rotated
            .landscapeLeft : { return ($0,$1) }, // not rotated
            .landscapeRight : { return ($0,$1) }, // not rotated
            .portraitUpsideDown : { return ($1,$0) }
        ]
        
        let (width_rot, height_rot): (Int, Int) = dimensionDict[orientation]!(self.width, self.height)
//        let width_rot = width, height_rot = height
        
        let pfmHeaderStr: NSString = "Pf\n\(width_rot) \(height_rot)\n-1\n" as NSString
        var pfmData = pfmHeaderStr.data(using: String.Encoding.utf8.rawValue)!
        
        print("using orientation = \(orientation.rawValue)")
        
        let arrlen: Int = width*height
        let arrlenm1: Int = arrlen-1    // for optimization in rotation calculation
        
        let rotate0: (Int) -> Int = { return $0 } // identity
        let rotate90cw: (Int) -> Int = {
            let x = $0 % self.width
            let y = $0 / self.width
            let x_ = self.height - y - 1
            let y_ = x
            let i_ = y_ * self.height + x_
            return i_
        }
        let rotate180: (Int) -> Int = { return arrlenm1 - $0 } // I think this works
        let rotate90ccw: (Int) -> Int = { return arrlenm1 - self.height * ($0 % self.width) - $0/self.width }
        let rotationDict: [AVCaptureVideoOrientation : (Int) -> Int] = [
            .portrait : rotate90ccw,
            .landscapeLeft : rotate0,
            .landscapeRight : rotate180,
            .portraitUpsideDown : rotate90cw,
        ]
    
        var pfmBodyArray: [Float] = Array<Float>(repeating: 0.0, count: arrlen)
        let rotator = rotationDict[orientation]!
        let flipper: (Int) -> Int = { (i0: Int) in
            let x0 = i0 % width_rot
            let y = i0 / width_rot
            let x = width_rot - x0 - 1
            return y * width_rot + x
        }
        
        for i in 0..<width*height {
            let val: Float
            if (unknownArray[i] == 0) {
                let code = valueArray[i]
                
                switch binaryCodeSystem {
                case .GrayCode:
                    let pos = decodeGrayCode(of: code)
                    val = Float(exactly: pos)!
                case .MinStripeWidthCode:
                    if code < UInt32(minSW_codeToPos!.count) {  // make sure codeToPos function defined for code
                        let pos = minSW_codeToPos![Int(code)]
                        val = Float(exactly: pos)!
                    } else {
                        val = Float.infinity
                    }
                }
            } else {
                val = Float.infinity
            }
            // rotates i
            // optimized way of calculating this?
            //let x_rot = height - i/width - 1
            //let y_rot = width - i%width - 1
            //let i_rot = y_rot*height + x_rot
            
//            let i_rot = arrlenm1 - height*(i%width) - i/width   // optimized version of calculation above
            let i_rot = flipper(rotator(i))
            pfmBodyArray[i_rot] = val
            
            // updated version: account for orientation in rotation
            
        }
        
        let pfmBodyData = Data(bytes: &pfmBodyArray, count: width*height*MemoryLayout<Float>.size)
        pfmData.append(pfmBodyData)
        
        return pfmData
    }
    
    
}


class PGMFile {
    var buffer: CVPixelBuffer
    var imageWidth: Int
    var imageHeight: Int
    
    let maxGray: UInt8 = 255
    let bufferLockFlags = CVPixelBufferLockFlags(rawValue: 0)
    var rotate: Bool
    
    private var header: NSString {
        get {
            if rotate {
                return "P5 \(imageHeight) \(imageWidth) \(maxGray)\n" as NSString
            } else {
                return "P5 \(imageWidth) \(imageHeight) \(maxGray)\n" as NSString
            }
        }
    }
    
    init(buffer: CVPixelBuffer, rotate: Bool = true) {
        self.buffer = buffer
        self.imageWidth = buffer.width
        self.imageHeight = buffer.height
        self.rotate = rotate
    }
    
    func getPGMData() -> Data {
        var data: Data = self.header.data(using: String.Encoding.utf8.rawValue)!
        
        CVPixelBufferLockBaseAddress(buffer, bufferLockFlags)
        
        let ptr = buffer.baseAddress!.bindMemory(to: UInt8.self, capacity: imageWidth*imageHeight*4)
        
        var body: [UInt8] = Array<UInt8>(repeating: 0, count: imageWidth*imageHeight)
        for i in 0..<imageWidth*imageHeight {
            let value = ptr.advanced(by: i*4).pointee
            if rotate {
                let i_rot = imageHeight*(i%imageWidth) + i/imageWidth   // rotates index so image upright
                body[i_rot] = value
            } else {
                body[i] = value
            }
        }
        
        CVPixelBufferUnlockBaseAddress(buffer, bufferLockFlags)
        
        data.append(&body, count: imageWidth*imageHeight)
        return data
    }
}


extension CMSampleBuffer {
    func save() -> Bool {
        guard let pixelbuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(self) else { return false }
        let img: CIImage = CIImage(cvPixelBuffer: pixelbuffer)
        let colorspace = CGColorSpaceCreateDeviceRGB()
        let jpegData: Data = CIContext().jpegRepresentation(of: img, colorSpace: colorspace, options: [kCGImageDestinationLossyCompressionQuality as String : 0.9])!
        
        func completionHandler(_ success: Bool, _ error: Error?) {
            if success {
                print("Successfully added photo to library.")
            }
        }
        
        PHPhotoLibrary.shared().performChanges( {
            let creationRequest = PHAssetCreationRequest.forAsset()
            creationRequest.addResource(with: PHAssetResourceType.photo, data: jpegData, options: nil)
        }, completionHandler: completionHandler(_:_:))
        return true
    }
    
}
