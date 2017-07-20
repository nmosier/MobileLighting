//
//  calibration_wrapper.cpp
//  MobileLighting
//
//  Created by Nicholas Mosier on 7/20/17.
//  Copyright © 2017 Nicholas Mosier. All rights reserved.
//

#include <stdio.h>

#include "calibration.h"

extern "C" int calibrateWithSettings(char *settingspath) {
    return runFromSettings(string(settingspath));
}
