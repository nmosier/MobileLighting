//
//  activeLighting_wrapper.cpp
//  demo
//
//  Created by Nicholas Mosier on 6/28/17.
//  Copyright © 2017 Nicholas Mosier. All rights reserved.
//

#include <stdio.h>
#include "ImgProcessor.h"

extern "C" void refineDecodedIm(char *outdir, int direction, char* decodedIm) {
    refine(outdir, direction, decodedIm);	// returns final CFloatImage, ignore
}

extern "C" void disparitiesOfRefinedImgs(char *posdir0, char *posdir1) {//, char *out0, char *out1, int dXmin, int dXmax, int dYmin, int dYmax) {
    // in0, in1 are flo images, need to create
    // so inputs should be to directories?
    CFloatImage x, y;
    CFloatImage merged0, merged1;
    char filename[1024];
    
    strcpy(filename, posdir0);
    strcat(filename, "/result0-4refined2.pfm");
    ReadImageVerb(x, filename, 0);
    strcpy(filename, posdir0);
    strcat(filename, "/result1-4refined2.pfm");
    ReadImageVerb(y, filename, 0);
    merged0 = mergeToFloImage(x, y);
    sprintf(filename, "%s/result.flo", posdir0);
    WriteFlowFile(merged0, filename);
    
    strcpy(filename, posdir1);
    strcat(filename, "/result0-4refined2.pfm");
    ReadImageVerb(x, filename, 0);
    strcpy(filename, posdir1);
    strcat(filename, "/result1-4refined2.pfm");
    ReadImageVerb(y, filename, 0);
    merged1 = mergeToFloImage(x, y);
    sprintf(filename, "%s/result.flo", posdir1);
    WriteFlowFile(merged1, filename);
    
    //computeDisparities(in0, in1, out0, out1, dXmin, dXmax, dYmin, dYmax);
}
