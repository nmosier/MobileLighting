//
//  calibwrapper.cpp
//  MobileLighting_Mac
//
//  Created by Nicholas Mosier on 6/15/18.
//  Copyright © 2018 Nicholas Mosier. All rights reserved.
//

#include <stdio.h>
#include <string>

int calibrateWithSettings(std::string);  // this is the function in calibrate.cpp
extern "C" int CalibrateWithSettings(const char *inputSettingsFile) {   // this is the wrapped function for bridging to swift
    return calibrateWithSettings(std::string(inputSettingsFile));
}
