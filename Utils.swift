//
//  Utils.swift
//  MobileLighting
//
//  Created by Nicholas Mosier on 7/18/17.
//  Copyright © 2017 Nicholas Mosier. All rights reserved.
//

import Foundation
import CoreVideo

func swift2Cstr(_ str: String) -> UnsafeMutablePointer<Int8> {
    let nsstr = str as NSString
    return UnsafeMutablePointer<Int8>(mutating: nsstr.utf8String!)
}

func makeDir(_ str: String) -> Void {
    do {
        try FileManager.default.createDirectory(atPath: str, withIntermediateDirectories: true, attributes: nil)
    } catch {
        print("make dir - error - could not make directory.")
    }
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
}
