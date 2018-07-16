//
//  MotionManager.swift
//  IMUCapture
//
//  Created by Nicholas Mosier on 6/26/18.
//  Copyright © 2018 Nicholas Mosier. All rights reserved.
//

import Foundation
import CoreMotion
import Yaml

class MotionRecorder {
    let manager: CMMotionManager = CMMotionManager()
    
    var samples = [CMDeviceMotion]()
    
//    var session: Int = 0
    
//    var timestampSamples = [TimeInterval]()
//    var accelerationSamples = [CMAcceleration]()
//    var attitudeSamples = [CMAttitude]()
    
    init(interval: Double = 0.01) {
        guard manager.isDeviceMotionAvailable else {
            print("device motion not available, aborting.")
            return
        }
        
        manager.deviceMotionUpdateInterval = interval
    }
    
    func startRecording() {
        samples.removeAll()
        manager.startDeviceMotionUpdates(using: manager.attitudeReferenceFrame, to: OperationQueue.main, withHandler: sampleDeviceMotion(_:_:))
    }
    
    func stopRecording() {
        manager.stopDeviceMotionUpdates()
    }
    
    func sampleDeviceMotion(_ motion: CMDeviceMotion?, _ error: Error?) {
        guard error == nil else {
            print(error!.localizedDescription)
            return
        }
        guard let motion = motion else {
            return
        }
        samples.append(motion)
    }
    
    func generateYML() -> String {
        let mainArr = samples.map { (sample: CMDeviceMotion) -> Yaml in
            let mag = sample.magneticField
            let magYML = Yaml.array([mag.field.x, mag.field.y, mag.field.z].map{return Yaml.double($0)})
            let acc = sample.userAcceleration
            let accYML = Yaml.array([acc.x, acc.y, acc.z].map{return Yaml.double($0)})
            let gyro = sample.rotationRate
            let gryoYML = Yaml.array([gyro.x, gyro.y, gyro.z].map{return Yaml.double($0)})
            let timeYML = Yaml.double(sample.timestamp - samples.first!.timestamp)
            let sampleDict = [
                Yaml.string("magneticField")    : magYML,
                Yaml.string("acceleration")     : accYML,
                Yaml.string("gryoscope")        : gryoYML,
                Yaml.string("time")             : timeYML,
            ]
            return Yaml.dictionary(sampleDict)
        }
        let mainYML = Yaml.array(mainArr)
        do { return try mainYML.save() }
        catch { fatalError("MotionRecorder: cannot generate YML file for IMU data.") }
    }
    
//    func saveSamples() {
//
//        var timestamps: String = ""
//        var accelerations: (String, String, String) = ("", "", "") // (x, y, z)
//        var attitudes: (String, String, String) = ("", "", "") // (pitch, roll, yaw)
//
//        if let initialTimestamp = timestampSamples.first {
//            self.timestampSamples = self.timestampSamples.map {
//                (timestamp: Double) -> Double in
//                return timestamp - initialTimestamp
//            }
//        }
//
//        if let initialAttitude = attitudeSamples.first {
//            self.attitudeSamples = self.attitudeSamples.map {
//                (attitude: CMAttitude) -> CMAttitude in
//                var attitude2 = attitude
//                attitude2.multiply(byInverseOf: initialAttitude)
//                return attitude2
//            }
//        }
//
//        for timestamp in timestampSamples {
//            timestamps += "\(timestamp)\n"
//        }
//
//        for acceleration in accelerationSamples {
//            accelerations.0 += "\(acceleration.x) "
//            accelerations.1 += "\(acceleration.y) "
//            accelerations.2 += "\(acceleration.z) "
//        }
//
//        for attitude in attitudeSamples {
//            attitudes.0 += "\(attitude.pitch) "
//            attitudes.1 += "\(attitude.roll) "
//            attitudes.2 += "\(attitude.yaw) "
//        }
//
//        //let path = NSHomeDirectory() + "/IMU"
//        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String
//        print(path)
//
//        do {
//            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
//
//            // save timestamps
//            try timestamps.write(toFile: path + "/times.txt", atomically: true, encoding: String.Encoding.ascii)
//
//            // save accelerations
//            try ("\(accelerations.0)\n\(accelerations.1)\n\(accelerations.2)").write(toFile: path + "/accelerations.txt", atomically: true, encoding: .ascii)
//
//            // save attitudes
//            try ("\(attitudes.0)\n\(attitudes.1)\n\(attitudes.2)").write(toFile: path + "/attitudes.txt", atomically: true, encoding: .ascii)
//
//        } catch let error {
//            print(error.localizedDescription)
//        }
//
//    }
}
