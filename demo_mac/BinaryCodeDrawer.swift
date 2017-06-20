import Foundation
import Cocoa
import CoreGraphics

let monitorTimeDelay: DispatchTimeInterval = .milliseconds(30)

enum BinaryCodeSystem {
    case GrayCode, MinStripeWidthCode
}

enum BinaryCodeOrdering {
    case NormalInvertedPairs
    case NormalThenInverted
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
    
    let context: NSGraphicsContext
    let frame: CGRect
    let width: Int
    let height: Int
    var drawHorizontally: Bool = false
    var drawInverted: Bool = false
    
    var bitmaps: [CGImage] = [CGImage]()
    var bitmaps_inverted: [CGImage] = [CGImage]()
    //var bitmap: Array<Pixel>
    var bitmap: UnsafeMutablePointer<UInt8>
    
    let blackHorizontalBar: Array<Pixel>
    let whiteHorizontalBar: Array<Pixel>
    init(context: NSGraphicsContext, frame: CGRect) {
        self.context = context
        self.frame = frame
        self.width = Int(frame.width)
        self.height = Int(frame.height)
        
        bitmap = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(width*height*4))
        blackHorizontalBar = Array<Pixel>(repeating: blackPixel, count: Int(width))
        whiteHorizontalBar = Array<Pixel>(repeating: whitePixel, count: Int(width))
    }
    
    func drawCode(forBit bit: Int, system: BinaryCodeSystem, horizontally: Bool? = nil, inverted: Bool? = nil, positionLimit: Int? = nil) {
        print("A: starting to draw code - \(timestampToString(date: Date()))")
        
        NSGraphicsContext.setCurrent(self.context)
        let context = self.context.cgContext
        let horizontally = horizontally ?? self.drawHorizontally
        let inverted = inverted ?? self.drawInverted       // temporarily use this configuration; does not change instance's settings
        
        var nPositions = horizontally ? height: width   // nPositions = # of diff. gray codes
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
            let fullBitArray = BinaryCodeDrawer.minStripeWidthCodeBitArrays![bit]
            bitArray = Array<Bool>(fullBitArray.prefix(Int(horizontally ? height : width)))
            guard nPositions <= bitArray.count else {
                print("BinaryCodeDrawer: ERROR — cannot display min stripe width code, number of stripes too large.")
                return
            }
            break
        }
        
        print("A0: starting to go thru loop - \(timestampToString(date: Date()))")
        
        var horizontalBar: Array<Pixel> = (inverted ? whiteHorizontalBar : blackHorizontalBar)
        let max: Int
        
        if !horizontally {
            // vertically
            max = nPositions
            var barVal: Bool
            for index in 0..<max {
                barVal = bitArray[index]
                horizontalBar[index] = (barVal == inverted) ? blackPixel : whitePixel
            }
            let data = Data(bytes: &horizontalBar, count: width*4)
            for row in 0..<height {
                data.copyBytes(to: bitmap.advanced(by: row*width*4), count: width*4)
            }
        } else {
            // horizontally
            max = width
            for row in 0..<height {
                let bar = (row < Int(nPositions)) ? ((bitArray[row] == inverted) ? blackHorizontalBar : whiteHorizontalBar) : (inverted ? whiteHorizontalBar : blackHorizontalBar)
                let data = Data(bytes: bar, count: width*4)
                data.copyBytes(to: bitmap.advanced(by: row*width*4), count: width*4)
            }
        }
 
        print("A1: finished generating bitmap - \(timestampToString(date: Date()))")
        
        let provider = CGDataProvider(data: NSData(bytes: bitmap, length: width*height*4))
        let colorspace: CGColorSpace = CGColorSpaceCreateDeviceRGB()
        let info: CGBitmapInfo = [CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)]
        let image = CGImage(width: width, height: height,
                            bitsPerComponent: 8, bitsPerPixel: 4*8, bytesPerRow: 4*width, space: colorspace, bitmapInfo: info, provider: provider!,
                            decode: nil, shouldInterpolate: true, intent: CGColorRenderingIntent.defaultIntent)
        context.draw(image!, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        print("B: finished drawing code - \(timestampToString(date: Date()))")
    }
    
    
}
