//
//  activeLighting_wrapper.cpp
//  demo
//
//  Created by Nicholas Mosier on 6/28/17.
//  Copyright © 2017 Nicholas Mosier. All rights reserved.
//

#include <stdio.h>
#include "ImgProcessor.h"

extern "C" void refineDecodedIm(char *outdir, int direction, char* decodedIm, double angle, int mode) {
    refine(outdir, direction, decodedIm, angle, mode);	// returns final CFloatImage, ignore
}

extern "C" void disparitiesOfRefinedImgs(char *posdir0, char *posdir1, char *outpos0, char *outpos1, int dXmin, int dXmax, int dYmin, int dYmax) {
    // in0, in1 are flo images, need to create
    // so inputs should be to directories?
    CFloatImage x, y;
    CFloatImage merged0, merged1;
    char filename[1000], in0[1000], in1[1000];
    
    // first create necessary FLO files for computeDisparities()
    sprintf(filename, "%s/result0-4refined2.pfm", posdir0);
    ReadImageVerb(x, filename, 0);
    sprintf(filename, "%s/result1-4refined2.pfm", posdir0);
    ReadImageVerb(y, filename, 0);
    merged0 = mergeToFloImage(x, y);
    sprintf(filename, "%s/result.flo", posdir0);
    WriteFlowFile(merged0, filename);
    strcpy(in0, filename);
    
    sprintf(filename, "%s/result0-4refined2.pfm", posdir1);
    ReadImageVerb(x, filename, 0);
    sprintf(filename, "%s/result1-4refined2.pfm", posdir1);
    ReadImageVerb(y, filename, 0);
    merged1 = mergeToFloImage(x, y);
    sprintf(filename, "%s/result.flo", posdir1);
    WriteFlowFile(merged1, filename);
    strcpy(in1, filename);
    
    computeDisparities(in0, in1, outpos0, outpos1, dXmin, dXmax, dYmin, dYmax);
}
