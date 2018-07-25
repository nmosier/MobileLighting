//
//  Utils.swift
//  MobileLighting
//
//  Created by Nicholas Mosier on 7/18/17.
//  Copyright © 2017 Nicholas Mosier. All rights reserved.
//

import Foundation
import CoreVideo
import CoreMedia
import Yaml


func makeDir(_ str: String) -> Void {
    do {
        try FileManager.default.createDirectory(atPath: str, withIntermediateDirectories: true, attributes: nil)
    } catch {
        print("make dir - error - could not make directory.")
    }
}

func getptr<T>(_ obj: inout [T]) -> UnsafeMutablePointer<T>? {
    return UnsafeMutablePointer<T>(&obj)
}

func getIDs(_ strs: [String], prefix: String, suffix: String) -> [Int] {
    return strs.map {
        return String($0.split(separator: "/").last!)
    }.map {
        guard $0.hasPrefix(prefix), $0.hasSuffix(suffix) else {
            return nil
        }
        let base = $0.dropFirst(prefix.count).dropLast(suffix.count)
        return Int(base)
    }.filter{
        return $0 != nil
        }.map{ return $0!}
}

let lockFlags = CVPixelBufferLockFlags(rawValue: 0) // read & write



// because the Swift standard library doesn't have a built-in linked list class,
// I wrote a minimalistic one. i'll add to it as needed
class List<T> {
    private class ListNode<T> {
        var head: T
        var tail: ListNode<T>?
        var parent: ListNode<T>?
        
        init(head: T, tail: ListNode<T>? = nil, parent: ListNode<T>? = nil) {
            self.head = head
            self.tail = tail
            self.parent = parent
            
            tail?.parent = self
            parent?.tail = self
        }
    }
    
    var count: Int = 0
    private var _first: ListNode<T>? = nil
    private weak var _last: ListNode<T>? = nil
    
    var first: T? {
        get {
            return _first?.head
        }
        set {
            guard let newValue = newValue else {
                return
            }
            _first?.head = newValue
        }
    }
    var last: T? {
        get {
            return _last?.head
        }
        set {
            guard let newValue = newValue else {
                return
            }
            _last?.head = newValue
        }
    }
    
    func insertFirst(_ obj: T) {
        _first = ListNode<T>(head: obj, tail: _first)
        _last = _last ?? _first
    }
    
    func popLast() -> T? {
        let value = _last?.head
        if _first === _last {
            _first = nil
            _last = nil
        } else {
            _last = _last?.parent
            _last?.tail = nil
        }
        return value
    }
    
    func removeAll() {
        self._first = nil
        self._last = nil
    }
}

// properly add C strings together (removes null byte from first)
func +(left: [CChar], right: [CChar]) -> [CChar] {
    var result = [CChar](left.dropLast())
    result.append(contentsOf: right)
    return result
}

prefix operator *
extension String {
    static prefix func * (swiftString: String) -> [CChar] {
        return swiftString.cString(using: .ascii)!
    }
}

prefix func * (swiftStringArray: [String]) -> [[CChar]] {
    return swiftStringArray.map {
        return *$0
    }
}

prefix operator **
prefix func ** (cStringArray: inout [[CChar]]) -> [UnsafeMutablePointer<CChar>?] {
    var ptrs = [UnsafeMutablePointer<CChar>?]()
    for i in 0..<cStringArray.count { ptrs.append(getptr(&cStringArray[i])) }
    return ptrs
}


func removeFiles(dir: String) -> Void {
    guard let paths = try? FileManager.default.contentsOfDirectory(atPath: dir) else {
        print("Could not remove files at directory \(dir).")
        return
    }
    for path in paths {
        do { try FileManager.default.removeItem(atPath: "\(dir)/\(path)") }
        catch let error { print(error.localizedDescription) }
    }
}

func partitionTokens(_ tokens: [String]) -> ([String], [String]) {
    let params = tokens.filter { return !$0.starts(with: "-") }
    let flags = tokens.filter { return $0.starts(with: "-") }
    return (params, flags)
}

extension CMTime {
    init(exposureDuration: Double) {
        let prefferedExposureDurationTimescale: CMTimeScale = 1000000
        self.init(seconds: exposureDuration, preferredTimescale: prefferedExposureDurationTimescale)
    }
}



// from https://stackoverflow.com/questions/32952248/get-all-enum-values-as-an-array
// temporary implementation of getting all cases of an Enum
// this can be replaced by CaseIterable protocol once Swift 4.2 and Xcode 10 are released (this summer 2018, I think)
protocol EnumCollection : Hashable {}
extension EnumCollection {
    static func cases() -> AnySequence<Self> {
        typealias S = Self
        return AnySequence { () -> AnyIterator<S> in
            var raw = 0
            return AnyIterator {
                let current : Self = withUnsafePointer(to: &raw) { $0.withMemoryRebound(to: S.self, capacity: 1) { $0.pointee }
                }
                guard current.hashValue == raw else { return nil }
                raw += 1
                return current
            }
        }
    }
}
extension String {
    subscript (i: Int) -> Character {
        return self[index(startIndex, offsetBy: i)]
    }
}

extension Dictionary where Key == Yaml, Value == Yaml {
    subscript (_ string: String) -> Yaml? {
        let key = Yaml.string(string)
        return self[key]
    }
}
