// swift-tools-version:3.1

import PackageDescription

let package = Package(
    name: "SerialTools",
    targets: [
        Target(
            name: "SwitcherCtrl",
            dependencies: ["SerialUtils"]
        ),
        Target(
            name: "VXMCtrl",
            dependencies: ["SerialUtils"]
        ),
        Target(name: "SerialUtils"),
    ],
    dependencies: [
        .Package(url: "https://github.com/yeokm1/SwiftSerial.git", majorVersion: 0),
    ]
)
