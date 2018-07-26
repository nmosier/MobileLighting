//
//  MobileLighting_Mac-Bridging-Header.h
// 
//
//  Created by Nicholas Mosier on 6/28/17.
//  Copyright © 2017 Nicholas Mosier. All rights reserved.
//

#ifndef MobileLighting_Mac_Bridging_Header_h
#define MobileLighting_Mac_Bridging_Header_h

#include "Parameters.h"

//MARK: Image Processor
#include "activeLighting/activeLighting.h"

// calibration functions
int calibrateWithSettings(char *settingspath);

void createSettingsIntrinsitcsChessboard(char *outputpath, char *imglistpath, char *templatepath);

//MARK: Robot Control
#include "RobotControl/RobotControl/RobotControl.h"

//MARK: Calibration
int CalibrateWithSettings(const char *inputSettingsFile);
int DetectionCheck(char *inputSettingsFile, char *imleft, char *imright);

#endif
