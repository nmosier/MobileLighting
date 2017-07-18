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

void refineDecodedIm(char *outdir, int direction, char *decodedIm);
//void disparitiesOfRefinedImgs(char *in0, char *in1, char *out0, char *out1, int dXmin, int dXmax, int dYmin, int dYmax);
void disparitiesOfRefinedImgs(char *dirpos0, char *dirpos1, char *outpos0, char *outpos1, int dXmin, int dXmax, int dYmin, int dYmax);
