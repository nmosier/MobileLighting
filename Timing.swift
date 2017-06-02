//
//  Timing.swift
//  
//
//  Created by Nicholas Mosier on 5/31/17.
//
//

import Foundation

// timestampToString(date:)
// -prints out minutes, seconds, and nanoseconds stored in Date object
// (for convenience when timing things)
func timestampToString(date: Date) -> String {
    let minutes = Calendar.current.component(.minute, from: date)
    let seconds = Calendar.current.component(.second, from: date)
    let nanoseconds = Calendar.current.component(.nanosecond, from: date)
    return "\(minutes):\(seconds):\(nanoseconds)"
}
