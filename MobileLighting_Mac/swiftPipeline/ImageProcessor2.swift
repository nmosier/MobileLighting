//
//  ImageProcessor2.swift
//  demo
//
//  Created by Nicholas Mosier on 6/28/17.
//  Copyright © 2017 Nicholas Mosier. All rights reserved.
//

import Foundation
import Darwin
import Yaml

func decodedImageHandler(_ decodedImPath: String, horizontal: Bool, projector: Int, position: Int) {
    /*
    let direction: Int = horizontal ? 1 : 0
    
    
    let outdir = dirStruc.subdir(dirStruc.refined, proj: projector, pos: position)
    let completionHandler: () -> Void = {
        let filepath = dirStruc.metadataFile(direction)
        do {
            let metadataStr = try String(contentsOfFile: filepath)
            let metadata: Yaml = try Yaml.load(metadataStr)
            if let angle: Double = metadata.dictionary?[Yaml.string("angle")]?.double {
                refineDecodedIm(swift2Cstr(outdir), horizontal ? 1:0, swift2Cstr(decodedImPath), angle)
            } else {
                print("refine error: could not load angle (double) from YML file.")
            }
        } catch {
            print("refine error: could not load metadata file.")
        }
    }
    photoReceiver.dataReceivers.insertFirst(
        SceneMetadataReceiver(completionHandler, path: dirStruc.metadataFile(direction))
    )
 */

}

//MARK: disparity matching functions
// uses bridged C++ code from ActiveLighting image processing pipeline
// NOTE: this decoding step is not yet automated; it must manually be executed from
//    the main command-line user input loop

// computes & saves disparity maps for images of the given image position pair taken with the given projector
// NOW: also refines disparity maps
func disparityMatch(proj: Int, leftpos: Int, rightpos: Int, rectified: Bool) {
    var refinedDirLeft: [CChar], refinedDirRight: [CChar]
//    if rectified {
//        refinedDirLeft = (dirStruc.subdir(dirStruc.refined, proj: proj, pos: leftpos) + "/left").cString(using: .ascii)!
//        refinedDirRight = (dirStruc.subdir(dirStruc.refined, proj: proj, pos: rightpos) + "/right").cString(using: .ascii)!
        refinedDirLeft = *dirStruc.decoded(proj: proj, pos: leftpos, rectified: rectified)
        refinedDirRight = *dirStruc.decoded(proj: proj, pos: rightpos, rectified: rectified)
//    } else {
////        refinedDirLeft = dirStruc.subdir(dirStruc.refined, proj: proj, pos: leftpos).cString(using: .ascii)!
////        refinedDirRight = dirStruc.subdir(dirStruc.refined, proj: proj, pos: rightpos).cString(using: .ascii)!
//        refinedDirLeft = *dirStruc
//    }
    var disparityDirLeft = *dirStruc.disparity(proj: proj, pos: leftpos, rectified: rectified)//*dirStruc.subdir(dirStruc.disparity(rectified), proj: proj, pos: leftpos)
    var disparityDirRight = *dirStruc.disparity(proj: proj, pos: rightpos, rectified: rectified)//*dirStruc.subdir(dirStruc.disparity(rectified), proj: proj, pos: rightpos)
    let l = Int32(leftpos)
    let r = Int32(rightpos)
    
    let xmin, xmax, ymin, ymax: Int32
    if (rectified) {
        xmin = -1080
        xmax = 1080
        ymin = -1
        ymax = 1
    } else {
        xmin = 0
        xmax = 0
        ymin = 0
        ymax = 0
    }
    disparitiesOfRefinedImgs(&refinedDirLeft, &refinedDirRight,
                             &disparityDirLeft,
                             &disparityDirRight,
                             l, r, rectified ? 1 : 0,
                             xmin, xmax, ymin, ymax)
    
    
    var in_suffix = "0initial".cString(using: .ascii)!
    var out_suffix = "1crosscheck1".cString(using: .ascii)!
    crosscheckDisparities(&disparityDirLeft, &disparityDirRight, l, r, 0.5, 0, 0, &in_suffix, &out_suffix)
    
    // if images are rectified, do not perform filter disparities
    if !rectified {
        return
    }
    
    var in_suffix_x = "/disp\(leftpos)\(rightpos)x-1crosscheck1.pfm".cString(using: .ascii)!
    var in_suffix_y = "/disp\(leftpos)\(rightpos)y-1crosscheck1.pfm".cString(using: .ascii)!
    var out_suffix_x = "/disp\(leftpos)\(rightpos)x-2filtered.pfm".cString(using: .ascii)!
    var out_suffix_y = "/disp\(leftpos)\(rightpos)y-2filtered.pfm".cString(using: .ascii)!
    
    var dispx, dispy, outx, outy: [CChar]
    
    dispx = disparityDirLeft + in_suffix_x
    dispy = disparityDirLeft + in_suffix_y
    outx = disparityDirLeft + out_suffix_x
    outy = disparityDirLeft + out_suffix_y
    filterDisparities(&dispx, &dispy, &outx, &outy, l, r, 0.75, 3, 0, 20, 200)
    
    dispx = disparityDirRight + in_suffix_x
    dispy = disparityDirRight + in_suffix_y
    outx = disparityDirRight + out_suffix_x
    outy = disparityDirRight + out_suffix_y
    
    filterDisparities(&dispx, &dispy, &outx, &outy, l, r, 0.75, 3, 0, 20, 200)
    in_suffix = "2filtered".cString(using: .ascii)!
    out_suffix = "3crosscheck2".cString(using: .ascii)!
    crosscheckDisparities(&disparityDirLeft, &disparityDirRight, l, r, 0.5, 1, 0, &in_suffix, &out_suffix)

}

func rectify(left: Int, right: Int, proj: Int) {
    var intr = dirStruc.intrinsicsYML.cString(using: .ascii)!
    var extr = dirStruc.extrinsicsYML(left: left, right: right).cString(using: .ascii)!
    let rectdirleft = dirStruc.decoded(proj: proj, pos: left, rectified: true)
    let rectdirright = dirStruc.decoded(proj: proj, pos: right, rectified: true)
    var result0l = *"\(dirStruc.decoded(proj: proj, pos: left, rectified: false))/result\(left)u-2holefilled.pfm"
    var result0r = *"\(dirStruc.decoded(proj: proj, pos: right, rectified: false))/result\(right)u-2holefilled.pfm"
    var result1l = *"\(dirStruc.decoded(proj: proj, pos: left, rectified: false))/result\(left)v-2holefilled.pfm"
    var result1r = *"\(dirStruc.decoded(proj: proj, pos: right, rectified: false))/result\(right)v-2holefilled.pfm"
    computeMaps(&result0l, &intr, &extr)

    var outpaths = [rectdirleft + "/result\(left)\(right)u-0rectified.pfm",
        rectdirleft + "/result\(left)\(right)v-0rectified.pfm",
        rectdirright + "/result\(left)\(right)u-0rectified.pfm",
        rectdirright + "/result\(left)\(right)v-0rectified.pfm",
        ]
    for path in outpaths {
        let dir = path.split(separator: "/").dropLast().joined(separator: "/")
        do { try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil) }
        catch { print("rectify: could not create dir at \(dir).") }
    }
    var coutpaths = outpaths.map {
        return $0.cString(using: .ascii)!
    }
    rectifyDecoded(0, &result0l, &coutpaths[0])
    rectifyDecoded(0, &result1l, &coutpaths[1])
    rectifyDecoded(1, &result0r, &coutpaths[2])
    rectifyDecoded(1, &result1r, &coutpaths[3])
}

// merge disparity maps for one stereo pair across all projectors
func merge(left leftpos: Int, right rightpos: Int, rectified: Bool) {
    var leftx, lefty: [[CChar]]
    var rightx, righty: [[CChar]]
    
    // search for projectors for which disparities have been computed for given left/right positions
    guard let projectorDirs = try? FileManager.default.contentsOfDirectory(atPath: "\(dirStruc.disparity(rectified))") else {
        print("merge: cannot find projectors directory at \(dirStruc.disparity(rectified))")
        return
    }
    let projectors = getIDs(projectorDirs, prefix: "proj", suffix: "")
    var positionDirs = projectors.map {
        return (dirStruc.disparity(proj: $0, pos: leftpos, rectified: rectified), dirStruc.disparity(proj: $0, pos: rightpos, rectified: rectified))
    }
//    var positionDirs: [(String, String)] = projectorDirs.map {
//        return ("\($0)/pos\(leftpos)", "\($0)/pos\(rightpos)")
//    }
    var pfmPathsLeft, pfmPathsRight: [(String, String)]
    if rectified {
        pfmPathsLeft = positionDirs.map {
            return ("\($0.0)/disp\(leftpos)\(rightpos)x-3crosscheck2.pfm", "\($0.0)/disp\(leftpos)\(rightpos)y-3crosscheck2.pfm")
        }
        pfmPathsRight = positionDirs.map {
            return ("\($0.1)/disp\(leftpos)\(rightpos)x-3crosscheck2.pfm", "\($0.1)/disp\(leftpos)\(rightpos)y-3crosscheck2.pfm")
        }
    } else {
        pfmPathsLeft = positionDirs.map {
            return ("\($0.0)/disp\(leftpos)\(rightpos)x-1crosscheck1.pfm", "\($0.0)/disp\(leftpos)\(rightpos)y-1crosscheck1.pfm")
        }
        pfmPathsRight = positionDirs.map {
            return ("\($0.1)/disp\(leftpos)\(rightpos)x-1crosscheck1.pfm", "\($0.1)/disp\(leftpos)\(rightpos)y-1crosscheck1.pfm")
        }
    }
    
    pfmPathsLeft = pfmPathsLeft.filter {
        let (leftx, lefty) = $0
        return FileManager.default.fileExists(atPath: leftx) && FileManager.default.fileExists(atPath: lefty)
    }
    pfmPathsRight = pfmPathsRight.filter {
        let (rightx, righty) = $0
        return FileManager.default.fileExists(atPath: rightx) && FileManager.default.fileExists(atPath: righty)
    }
    
    leftx = pfmPathsLeft.map{ return $0.0 }.map{ return $0.cString(using: .ascii)! }
    lefty = pfmPathsLeft.map{ return $0.1 }.map{ return $0.cString(using: .ascii)! }
    rightx = pfmPathsRight.map{ return $0.0 }.map{ return $0.cString(using: .ascii)! }
    righty = pfmPathsRight.map{ return $0.1 }.map{ return $0.cString(using: .ascii)! }
    
    var imgsx = [UnsafeMutablePointer<Int8>?]()
    var imgsy = [UnsafeMutablePointer<Int8>?]()
    var outx = [CChar]()
    var outy = [CChar]()
    
    
    
    for i in 0..<leftx.count {
        imgsx.append(getptr(&leftx[i]))
    }
    for i in 0..<lefty.count {
        imgsy.append(getptr(&lefty[i]))
    }
//    var leftout = dirStruc.merged(pos: leftpos, rectified: rectified).cString(using: .ascii)!
    if rectified {
        outx = (dirStruc.merged(pos: leftpos, rectified: rectified) + "/disp\(leftpos)\(rightpos)x-0initial.pfm").cString(using: .ascii)!
        outy = (dirStruc.merged(pos: leftpos, rectified: rectified) + "/disp\(leftpos)\(rightpos)y-0initial.pfm").cString(using: .ascii)!
    } else {
        outx = (dirStruc.merged(pos: leftpos, rectified: rectified) + "/disp\(leftpos)\(rightpos)x.pfm").cString(using: .ascii)!
        outy = (dirStruc.merged(pos: leftpos, rectified: rectified) + "/disp\(leftpos)\(rightpos)y.pfm").cString(using: .ascii)!
    }
    
    let mingroup: Int32 = 2
    let maxdiff: Float = 1.0
    mergeDisparities(&imgsx, &imgsy, &outx, &outy, Int32(imgsx.count), mingroup, maxdiff)
    
    imgsx.removeAll()
    imgsx = [UnsafeMutablePointer<Int8>?]()
    imgsy = [UnsafeMutablePointer<Int8>?]()
    for i in 0..<rightx.count {
        imgsx.append(getptr(&rightx[i]))
    }
    imgsy.removeAll()
    for i in 0..<righty.count {
        imgsy.append(getptr(&righty[i]))
    }
    
    if rectified {
        outx = (dirStruc.merged(pos: rightpos, rectified: rectified) + "/disp\(leftpos)\(rightpos)x-0initial.pfm").cString(using: .ascii)!
        outy = (dirStruc.merged(pos: rightpos, rectified: rectified) + "/disp\(leftpos)\(rightpos)y-0initial.pfm").cString(using: .ascii)!
    } else {
        outx = (dirStruc.merged(pos: rightpos, rectified: rectified) + "/disp\(leftpos)\(rightpos)x.pfm").cString(using: .ascii)!
        outy = (dirStruc.merged(pos: rightpos, rectified: rectified) + "/disp\(leftpos)\(rightpos)y.pfm").cString(using: .ascii)!
    }
//    var rightout = dirStruc.merged(pos: rightpos, rectified: rectified).cString(using: .ascii)!
//    mergeDisparities(&imgsx, &imgsy, &rightout, Int32(imgsx.count), mingroup, maxdiff)
    mergeDisparities(&imgsx, &imgsy, &outx, &outy, Int32(imgsx.count), mingroup, maxdiff)
    
    if rectified {
        var posdir0 = dirStruc.merged(pos: leftpos, rectified: true).cString(using: .ascii)!
        var posdir1 = dirStruc.merged(pos: rightpos, rectified: true).cString(using: .ascii)!
        let l = Int32(leftpos)
        let r = Int32(rightpos)
        let thresh: Float = 0.5
        let xonly: Int32 = 1
        let halfocc: Int32 = 0
        var in_suffix = "0initial".cString(using: .ascii)!
        var out_suffix = "1crosscheck".cString(using: .ascii)!
        crosscheckDisparities(&posdir0, &posdir1, l, r, thresh, xonly, halfocc, &in_suffix, &out_suffix)
    }
}

// reprojects merged 
func reproject(left leftpos: Int, right rightpos: Int) {
    let projDirs = try! FileManager.default.contentsOfDirectory(atPath: dirStruc.disparity(true))
    let projectors = getIDs(projDirs.map{return String($0.split(separator: "/").last!)}, prefix: "proj", suffix: "")
    
    for proj in projectors {
        for pos in [leftpos, rightpos] {
            var dispx: [CChar], dispy: [CChar], codex: [CChar], codey: [CChar], outx: [CChar], outy: [CChar], errfile: [CChar], matfile: [CChar], logfile: [CChar]

            dispx = *(dirStruc.merged(pos: pos, rectified: true) + "/disp\(leftpos)\(rightpos)x-1crosscheck.pfm")
            dispy = *(dirStruc.merged(pos: pos, rectified: true) + "/disp\(leftpos)\(rightpos)y-1crosscheck.pfm")
            codex = *"\(dirStruc.decoded(proj: proj, pos: pos, rectified: true))/result\(leftpos)\(rightpos)u-4refined2.pfm"
            codey = *"\(dirStruc.decoded(proj: proj, pos: pos, rectified: true))/result\(leftpos)\(rightpos)v-4refined2.pfm"
            outx = (dirStruc.reprojected(proj: proj, pos: pos) + "/disp\(leftpos)\(rightpos)x-0initial.pfm").cString(using: .ascii)!
            outy = (dirStruc.reprojected(proj: proj, pos: pos) + "/disp\(leftpos)\(rightpos)y-0initial.pfm").cString(using: .ascii)!
            errfile = (dirStruc.reprojected(proj: proj, pos: pos) + "/error\(leftpos)\(rightpos).pfm").cString(using: .ascii)!
            matfile = (dirStruc.reprojected(proj: proj, pos: pos) + "/mat\(leftpos)\(rightpos).txt").cString(using: .ascii)!
            logfile = *(dirStruc.reprojected(proj: proj, pos: pos) + "/log\(leftpos)\(rightpos).txt")
            reprojectDisparities(&dispx, &dispy, &codex, &codey, &outx, &outy, &errfile, &matfile, &logfile)
            
            /*
            need to add code for using nonlinear reprojection -- but need warpdisp code first.
            */
            
            var dir = *dirStruc.reprojected(proj: proj, pos: pos)
            
            var in_suffix_x = *"/disp\(leftpos)\(rightpos)x-0initial.pfm"
            var out_suffix_x = *"/disp\(leftpos)\(rightpos)x-1filtered.pfm"
            var out_suffix_y = *"/disp\(leftpos)\(rightpos)y-1filtered.pfm"
            
            dispx = dir + in_suffix_x
            outx = dir + out_suffix_x
            outy = dir + out_suffix_y
            
            filterDisparities(&dispx, nil, &outx, nil, Int32(leftpos), Int32(rightpos), -1, 3, 0, 0, 200)
        }
    }
}

func mergeReprojected(left leftpos: Int, right rightpos: Int) {
    
    for pos in [leftpos, rightpos] {
        var premerged = *(dirStruc.merged(pos: pos, rectified: true) + "/disp\(leftpos)\(rightpos)x-1crosschecked.pfm")
        
        var dispProjectors = getIDs(try! FileManager.default.contentsOfDirectory(atPath: dirStruc.disparity(true)), prefix: "proj", suffix: "")
        // viewDisps: [[CChar]], contains all cross-checked, filtered PFM files that exist
        var viewDisps = *dispProjectors.map {
            return dirStruc.disparity(proj: $0, pos: pos, rectified: true) + "/disp\(leftpos)\(rightpos)x-2filtered.pfm"
            }.filter {
                return FileManager.default.fileExists(atPath: $0, isDirectory: nil)
        }
        var viewDispsPtrs = **viewDisps
        let nV = Int32(viewDisps.count)
        
        let reprojProjectors = getIDs(try! FileManager.default.contentsOfDirectory(atPath: dirStruc.reprojected), prefix: "proj", suffix: "")
        let reprojDirs = reprojProjectors.map {
            return dirStruc.reprojected(proj: $0, pos: pos)
        }

        let filteredReprojDirs = filterReliableReprojected(reprojDirs, left: leftpos, right: rightpos)
        var reprojDisps = *filteredReprojDirs.map { return $0 + "/disp\(leftpos)\(rightpos)x-1filtered.pfm" }
        var reprojDispsPtrs = **reprojDisps
        let nR = Int32(reprojDisps.count)
        
        var inmdfile = *(dirStruc.merged(pos: pos, rectified: true) + "/disp\(leftpos)\(rightpos)x-1crosscheck.pfm")
            
        var outdfile = *(dirStruc.merged2(pos) + "/disp\(leftpos)\(rightpos)x-0initial.pfm")
        var outsdfile = *(dirStruc.merged2(pos) + "/disp\(leftpos)\(rightpos)x-sd.pfm")
        var outnfile = *(dirStruc.merged2(pos) + "/disp\(leftpos)\(rightpos)x-nsamples.pgm")
        
         mergeDisparityMaps2(MERGE2_MAXDIFF, nV, nR, &outdfile, &outsdfile, &outnfile, &inmdfile, &viewDispsPtrs, &reprojDispsPtrs)
        
        // filter merged results
        var indispx = outdfile
        var outx = *(dirStruc.merged2(pos) + "/disp\(leftpos)\(rightpos)x-1filtered.pfm")
        filterDisparities(&indispx, nil, &outx, nil, Int32(leftpos), Int32(rightpos), -1, 0, 0, 20, 20)

    }
    
    // crosscheck filtered results
    var leftdir = *(dirStruc.merged2(leftpos))
    var rightdir = *(dirStruc.merged2(rightpos))
    var in_suffix = *"1filtered"
    var out_suffix = *"2crosscheck1"
    crosscheckDisparities(&leftdir, &rightdir, Int32(leftpos), Int32(rightpos), 1.0, 1, 1, &in_suffix, &out_suffix)
    
    // filter again, this can fill small holes of cross-checked regions
    for pos in [leftpos, rightpos] {
        var indispx = *(dirStruc.merged2(pos) + "/disp\(leftpos)\(rightpos)x-2crosscheck1.pfm")
        var outx = *(dirStruc.merged2(pos) + "/disp\(leftpos)\(rightpos)x-3filtered.pfm")
        filterDisparities(&indispx, nil, &outx, nil, Int32(leftpos), Int32(leftpos), -1, 0, 0, 20, 20)
    }
    
    // crosscheck one last time
    in_suffix = *"3filtered"
    out_suffix = *"4crosscheck2"
    crosscheckDisparities(&leftdir, &rightdir, Int32(leftpos), Int32(rightpos), 1, 1, 1, &in_suffix, &out_suffix)
}

func filterReliableReprojected(_ reprojDirs: [String], left leftpos: Int, right rightpos: Int) -> [String] {
    return reprojDirs.filter {
        let logFile = $0 + "/log\(leftpos)\(rightpos).txt"
        let logLines: [String] = (try! String(contentsOfFile: logFile)).split(separator: "\n").map { return String($0) }
        let logTokens: [[String]] = logLines.map {
            return $0.split(separator: " ").map { return String($0) }
        }
        let logVals: [[Double]] = logTokens.map {
            return $0.filter {
                return Double($0) != nil
                }.map {
                    return Double($0)!
            }
        }
        let frac0 = logVals[0][0], frac1 = logVals[1][0]
        let rms0 = logVals[0][1], rms1 = logVals[1][1]
        let bad0 = logVals[0][2], bad1 = logVals[1][2]
        let thresh0 = logVals[0][3], thresh1 = logVals[1][3]
        let fracfrac = frac1 / frac0 // fraction of reproj frac vs orig frac
        
        let reliable = fracfrac >= 0.3 && frac1 >= 5 && bad0 <= 50 && bad1 <= 10 && rms1 <= 0.75
        print((reliable ? "reliable: " : "not reliable: ") + logFile )
        return reliable
    }
}
