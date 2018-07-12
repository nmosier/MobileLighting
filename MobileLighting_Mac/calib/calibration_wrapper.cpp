//
//  calibwrapper.cpp
//  MobileLighting_Mac
//
//  Created by Nicholas Mosier on 6/15/18.
//  Copyright © 2018 Nicholas Mosier. All rights reserved.
//

#include <stdio.h>
#include <string>
#include <vector>

int calibrateWithSettings(std::string);  // this is the function in calibrate.cpp
extern "C" int CalibrateWithSettings(const char *inputSettingsFile) {   // this is the wrapped function for bridging to swift
    return calibrateWithSettings(std::string(inputSettingsFile));
}

std::vector<int> detectionCheck(char *inputSettingsFilepath, char *imleftpath, char *imrightpath);
extern "C" int DetectionCheck(char *inputSettingsFile, char *imleft, char *imright) {
    printf("inputsettings=%s, imleft=%s, imright=%s", inputSettingsFile, imleft, imright);
    std::vector<int> result = detectionCheck(inputSettingsFile, imleft, imright);
    return -1;
}
