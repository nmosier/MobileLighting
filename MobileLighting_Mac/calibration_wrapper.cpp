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

extern "C" void createSettingsIntrinsitcsChessboard(char *outputpath, char *imglistpath, char *templatepath) {
    FileStorage fs = FileStorage(templatepath, FileStorage::READ);
    Settings settings;
    string tmp;
    settings.read(fs.getFirstTopLevelNode());
    settings.imageListFilename = string(imglistpath);
    
    FileStorage settings_out(outputpath, FileStorage::WRITE);
    
    settings_out << "Settings";
    settings.write(settings_out);
}

//extern "C" void createImageList(
