import Foundation
import CoreImage

//MARK: Custom kernel strings
class CustomKernelStrings {
    
    static let ExtremeIntensities =  "kernel vec4 extremes( sampler im1, sampler im2 ) {" +
    "vec4 pix1, pix2, pixD;" +
    "pix1 = sample(im1, samplerCoord(im1));" +
    "pix2 = sample(im2, samplerCoord(im2));" +
    "pix1.r = pix1.r - 0.5;" +
    "pix2.r = pix2.r - 0.5;" +
    "if (abs(pix1.r) >= abs(pix2.r)) {" +
    "pixD.r = pix1.r + 0.5;" +
    "} else {" +
    "pixD.r = pix2.r + 0.5;" +
    "}" +
    "pixD.g = pixD.b = pixD.r;" +
    "pixD.a = 1.0;" +
    "return pixD;" +
    "}"

    
    static let IntensityDifference = "kernel vec4 difference( sampler imageN, sampler imageI ) {" +
        "vec4 pixN = sample(imageN, samplerCoord(imageN));" +
        "vec4 pixI = sample(imageI, samplerCoord(imageI));" +
        "vec4 pixDiff;" +
        "pixDiff = clamp(pixN - pixI + 0.5, 0.0, 1.0);" +
        "pixDiff.a = 1.0;" +
        "return pixDiff;" +
        "}"
    
    static let Grayscale = "kernel vec4 grayscale( sampler image, vec3 rgbWeights ) {" +
        "vec4 pix = sample(image, samplerCoord(image));" +
        "vec3 weights = rgbWeights;" +
        "float weightSum = rgbWeights[0] + rgbWeights[1] + rgbWeights[2];" +
        "weights = weights / weightSum;" +
        "pix.r = pix.g = pix.b = dot(pix.rgb, weights);" +
        "pix.a = 1.0;" +
        "return pix;" +
        "}"
    
    static let Threshold = "kernel vec4 threshold ( sampler imIn, float thresh ) {\nvec4 pix = sample(imIn, samplerCoord(imIn));\n//if (pix.r < thresh) pix.r = 0.0;\n//else if (pix.r + thresh > 1.0) pix.r = 1.0;\n//else pix.r = 0.5;\n    if (pix.r-0.5 >= thresh) pix.r = 1.0;\n    else if (0.5-pix.r >= thresh) pix.r = 0.0;\n    else pix.r = 0.5;\npix.g = pix.b = pix.r;\nreturn pix;\n}\n"
    
    static let Threshold2 = "kernel vec4 threshold ( sampler imIn, float thresh, float dir ) {\nvec2 coords = samplerCoord(imIn);\nvec2 origin = samplerOrigin(imIn);\nvec2 bound = origin + samplerSize(imIn);\nvec4 pix_c = sample(imIn, coords);\n\nif ( (dir == 0.0 && (coords.x <= origin.x || coords.x >= bound.x)) || (dir != 0.0 && (coords.y <= origin.y || coords.y >= bound.y)) ) {\n// apply old fallback logic\nif (pix_c.r-0.5 >= thresh) pix_c.r = 1.0;\nelse if (0.5-pix_c.r >= thresh) pix_c.r = 0.0;\nelse pix_c.r = 0.5;\n\npix_c.r = 0.0;// TEMP\n} else {\nif (pix_c.r-0.5 >= thresh) pix_c.r = 1.0;\nelse if (0.5-pix_c.r >= thresh) pix_c.r = 0.0;\nelse pix_c.r = 0.5;\n\npix_c.r = 0.0;\n}\n\npix_c.g = pix_c.b = pix_c.r;\nreturn pix_c;\n}"
}

func getKernelString(from filepath: String) -> String {
    var kernel: String
    var result = String()
    var chars: String.CharacterView
    do {
        kernel = try String(contentsOfFile: filepath)
    } catch {
        print("getKernelString: error reading file.")
        return ""
    }
    chars = kernel.characters
    for c in chars {
        if c == "\t" {break}
        else if c == "\n" {result.append("\\n")}
        else {result.append(c)}
    }
    return result
}

//MARK: Custom kernels
let ExtremeIntensityKernel = CIColorKernel(string: CustomKernelStrings.ExtremeIntensities)!
let IntensityDifferenceKernel = CIColorKernel(string: CustomKernelStrings.IntensityDifference)!
let GrayscaleKernel = CIColorKernel(string: CustomKernelStrings.Grayscale)!
let ThresholdKernel = CIColorKernel(string: CustomKernelStrings.Threshold)!
let ThresholdKernel2 = CIKernel(string: CustomKernelStrings.Threshold2)!

//MARK: Custom filters

class ExtremeIntensitiesFilter: CIFilter {
    var inputImage: CIImage?
    var inputBackgroundImage: CIImage?
    
    override var attributes: [String : Any] {
        return [
            kCIAttributeFilterDisplayName : "ExtremeIntensitiesFilter" as Any,
            kCIInputImageKey : [
                kCIAttributeIdentity : 0,
                kCIAttributeClass : "CIImage",
                kCIAttributeDisplayName : "Image",
                kCIAttributeType : kCIAttributeTypeImage],
            kCIInputBackgroundImageKey : [
                kCIAttributeIdentity : 0,
                kCIAttributeClass: "CIImage",
                kCIAttributeDisplayName : "Background Image",
                kCIAttributeType : kCIAttributeTypeImage]
        ]
    }
    
    override public var outputImage: CIImage? {
        get {
            if let inputImage = self.inputImage,
                let inputBackgroundImage = self.inputBackgroundImage {
                let args = [inputImage as Any, inputBackgroundImage as Any]
                return ExtremeIntensityKernel.apply(withExtent: inputImage.extent, arguments: args)
            } else {
                return nil
            }
        }
    }
}

class IntensityDifferenceFilter: CIFilter {
    var inputImage: CIImage?
    var inputBackgroundImage: CIImage?
    
    override var attributes: [String : Any] {
        return [
            kCIAttributeFilterDisplayName : "ExtremeIntensitiesFilter" as Any,
            kCIInputImageKey : [
                kCIAttributeIdentity : 0,
                kCIAttributeClass : "CIImage",
                kCIAttributeDisplayName : "Image",
                kCIAttributeType : kCIAttributeTypeImage],
            kCIInputBackgroundImageKey : [
                kCIAttributeIdentity : 0,
                kCIAttributeClass: "CIImage",
                kCIAttributeDisplayName : "Background Image",
                kCIAttributeType : kCIAttributeTypeImage]
        ]
    }
    
    override public var outputImage: CIImage? {
        get {
            if let inputImage = self.inputImage,
                let inputBackgroundImage = self.inputBackgroundImage {
                let args = [inputImage as Any, inputBackgroundImage as Any]
                return IntensityDifferenceKernel.apply(withExtent: inputImage.extent, arguments: args)
            } else {
                return nil
            }
        }
    }
}

class GrayscaleFilter: CIFilter {
    static let kCIRGBWeightsKey = "RGBWeights"
    var inputImage: CIImage?
    var RGBWeights: [Float]?
    
    override var attributes: [String : Any] {
        return [
            kCIAttributeFilterDisplayName : "GrayscaleFilter" as Any,
            kCIInputImageKey : [
                kCIAttributeIdentity : 0,
                kCIAttributeClass : "CIImage",
                kCIAttributeDisplayName : "Image",
                kCIAttributeType : kCIAttributeTypeImage],
            GrayscaleFilter.kCIRGBWeightsKey : [
                kCIAttributeIdentity : 0,
                kCIAttributeClass: "[Float]",
                kCIAttributeDisplayName : "RGB Weights",
                kCIAttributeType : kCIAttributeTypePosition3]
        ]
    }
    
    override public var outputImage: CIImage? {
        get {
            if let inputImage = self.inputImage {
                let args: [Any]
                if let RGBWeights = self.RGBWeights, RGBWeights.count == 3 {
                    let weights = RGBWeights.map { (float: Float) -> CGFloat in
                        return CGFloat(float)
                    }
                    let vector: CIVector = CIVector(x: weights[0], y: weights[1], z: weights[2])
                    args = [inputImage as Any, vector as Any]
                } else {
                    args = [inputImage as Any, CIVector(x: 1.0/3, y: 1.0/3, z: 1.0/3) as Any]
                }
                return GrayscaleKernel.apply(withExtent: inputImage.extent, arguments: args)
            } else {
                return nil
            }
        }
    }
}

class ThresholdFilter: CIFilter {
    static let kCIInputThresholdKey = "inputThresholdGrayscale"
    var inputImage: CIImage?
    var inputThresholdGrayscale: Float? // on range 0.0 ≤ 1.0, where 0.0 means [0, 0] -> 0 & [255, 255] -> 1
                                        // 1.0 means [0, 127] -> 0, [128, 255] -> 1
    
    override var attributes: [String : Any] {
        return [
            kCIAttributeFilterDisplayName : "ThresholdFilter" as Any,
            kCIInputImageKey : [
                kCIAttributeIdentity : 0,
                kCIAttributeClass : "CIImage",
                kCIAttributeDisplayName : "Image",
                kCIAttributeType : kCIAttributeTypeImage],
            ThresholdFilter.kCIInputThresholdKey : [
                kCIAttributeIdentity : 1,
                kCIAttributeClass: "Float",
                kCIAttributeDisplayName : "Threshold",
                kCIAttributeType : kCIAttributeTypeScalar]
        ]
    }
    
    override public var outputImage: CIImage? {
        get {
            if let inputImage = self.inputImage {
                // compute threshold_float, which is max val for black pixel (0)
                //let threshold_float = 0.5 - (inputThresholdGrayscale ?? thresholdDefault)*0.5
                let args = [inputImage as Any, thresholdDefault as Any]
                return ThresholdKernel.apply(withExtent: inputImage.extent, arguments: args)
            } else {
                return nil
            }
        }
    }
}

class ThresholdFilter2: CIFilter {
    static let kCIInputThresholdKey = "inputThresholdGrayscale"
    var inputImage: CIImage?
    var inputThresholdGrayscale: Float? // on range 0.0 ≤ 1.0, where 0.0 means [0, 0] -> 0 & [255, 255] -> 1
    // 1.0 means [0, 127] -> 0, [128, 255] -> 1
    var direction: Bool?
    
    override var attributes: [String : Any] {
        return [
            kCIAttributeFilterDisplayName : "ThresholdFilter2" as Any,
            kCIInputImageKey : [
                kCIAttributeIdentity : 0,
                kCIAttributeClass : "CIImage",
                kCIAttributeDisplayName : "Image",
                kCIAttributeType : kCIAttributeTypeImage],
            ThresholdFilter.kCIInputThresholdKey : [
                kCIAttributeIdentity : 1,
                kCIAttributeClass: "Float",
                kCIAttributeDisplayName : "Threshold",
                kCIAttributeType : kCIAttributeTypeScalar]
        ]
    }
    
    override public var outputImage: CIImage? {
        get {
            if let inputImage = self.inputImage {
                // compute threshold_float, which is max val for black pixel (0)
                let threshold_float = NSNumber(value: inputThresholdGrayscale ?? thresholdDefault)
                guard threshold_float.floatValue >= 0.0 && threshold_float.floatValue <= 0.5 else {
                    print("ThresholdFilter2: ERROR - threshold val must be between 0.0 and 0.5.")
                    return nil
                }
                let dir: Float = (direction ?? binaryCodeDirection!) ? 1.0 : 0.0  // b/c image rotated
                print("Thresholdfilter2: direction: \(dir)")
                let args = [inputImage as Any, threshold_float as Any, NSNumber(value: dir) as Any]
                
                func callback(index: Int32, rect: CGRect) -> CGRect {
                    return rect
                }
                return ThresholdKernel2.apply(withExtent: inputImage.extent, roiCallback: callback, arguments: args)
            } else {
                return nil
            }
        }
    }
}
