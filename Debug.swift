//
//  Debug.swift
//  MobileLighting
//
//  Created by Nicholas Mosier on 5/28/18.
//

import Foundation

let shouldSaveOriginals = false
let shouldSendThreshImgs = false

// thresholding parameters
let threshold_val = 0.035

// refinement parameters
let maxdiff0: Float = 1.0
let maxdiff1: Float = 0.1

// rectification
let shouldRectifyOnPhone = true
let stereoPosition = 1 // change laters

// photo capture
let defaultResolution = "high"

// robot control
let robotAcceleration: Float = 0.3
let robotVelocity: Float = 0.3
