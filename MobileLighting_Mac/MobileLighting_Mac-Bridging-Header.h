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
void refineDecodedIm(char *outdir, int direction, char* decodedIm, double angle, char *posID);
void disparitiesOfRefinedImgs(char *posdir0, char *posdir1, char *outdir0, char *outdir1, int pos0, int pos1, int rectified, int dXmin, int dXmax, int dYmin, int dYmax);
void computeMaps(char *impath, char *intr, char *extr);
void rectifyDecoded(int camera, char *impath, char *outpath);
void rectifyAmbient(int camera, char *impath, char *outpath);
void crosscheckDisparities(char *posdir0, char *posdir1, int pos0, int pos1, float thresh, int xonly, int halfocc, char *in_suffix, char *out_suffix);
void filterDisparities(char *dispx, char *dispy, char *outx, char *outy, int pos0, int pos1, float ythresh, int kx, int ky, int mincompsize, int maxholesize);
void mergeDisparities(char *imgsx[], char *imgsy[], char *outx, char *outy, int count, int mingroup, float maxdiff);
void reprojectDisparities(char *dispx_file, char *dispy_file, char *codex_file, char *codey_file, char *outx_file, char *outy_file, char *err_file, char *mat_file, char *log_file);
void mergeDisparityMaps2(float maxdiff, int nV, int nR, char* outdfile, char* outsdfile, char* outnfile, char *inmdfile, char **invdfiles, char **inrdfiles);

// calibration functions
int calibrateWithSettings(char *settingspath);

void createSettingsIntrinsitcsChessboard(char *outputpath, char *imglistpath, char *templatepath);

//MARK: Robot Control
#include "RobotControl/RobotControl/RobotControl.h"

//MARK: Calibration
int CalibrateWithSettings(const char *inputSettingsFile);
int DetectionCheck(char *inputSettingsFile, char *imleft, char *imright);

#endif
