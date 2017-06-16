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
}

//MARK: Custom kernels
let ExtremeIntensityKernel = CIColorKernel(string: CustomKernelStrings.ExtremeIntensities)!
let IntensityDifferenceKernel = CIColorKernel(string: CustomKernelStrings.IntensityDifference)!
let GrayscaleKernel = CIColorKernel(string: CustomKernelStrings.Grayscale)!

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
