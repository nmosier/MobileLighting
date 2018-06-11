//
//  MobileLighting_Mac-Bridging-Header.h
// 
//
//  Created by Nicholas Mosier on 6/28/17.
//  Copyright © 2017 Nicholas Mosier. All rights reserved.
//

#ifndef MobileLighting_Mac_Bridging_Header_h
#define MobileLighting_Mac_Bridging_Header_h


#endif


//MARK: Image Processor
void refineDecodedIm(char *outdir, int direction, char *decodedIm, double angle);
//void disparitiesOfRefinedImgs(char *in0, char *in1, char *out0, char *out1, int dXmin, int dXmax, int dYmin, int dYmax);
void disparitiesOfRefinedImgs(char *posdir0, char *posdir1, char *outdir0, char *outdir1, int pos0, int pos1, int dXmin, int dXmax, int dYmin, int dYmax);
void rectifyPFMs(int nimages, int camera, char *destdir, char **matrices, char **images);

// calibration functions
int calibrateWithSettings(char *settingspath);

void createSettingsIntrinsitcsChessboard(char *outputpath, char *imglistpath, char *templatepath);

//MARK: Robot Control
int Client();
int Server();
int Next();
int Restore();
