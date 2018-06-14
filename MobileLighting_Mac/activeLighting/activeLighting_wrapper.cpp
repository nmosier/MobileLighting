//
//  activeLighting_wrapper.cpp
//  demo
//
//  Created by Nicholas Mosier on 6/28/17.
//  Copyright © 2017 Nicholas Mosier. All rights reserved.
//

#include <stdio.h>
#include "ImgProcessor.h"
#include "Rectify.hpp"
#include "Utils.h"

extern "C" void refineDecodedIm(char *outdir, int direction, char* decodedIm, double angle) {
    refine(outdir, direction, decodedIm, angle);	// returns final CFloatImage, ignore
}

extern "C" void disparitiesOfRefinedImgs(char *posdir0, char *posdir1, char *outdir0, char *outdir1, int pos0, int pos1, int dXmin, int dXmax, int dYmin, int dYmax) {
    // in0, in1 are flo images, need to create
    // so inputs should be to directories?
    int verbose = 1;
    
    CFloatImage x, y;
    CFloatImage merged0, merged1;
    CFloatImage fdisp0, fdisp1;
    char filename[1000]; //, in0[1000], in1[1000];
    
    // first create necessary FLO files for computeDisparities()
    sprintf(filename, "%s/result0-4refined2.pfm", posdir0);
    ReadImageVerb(x, filename, 0);
    sprintf(filename, "%s/result1-4refined2.pfm", posdir0);
    ReadImageVerb(y, filename, 0);
    merged0 = mergeToFloImage(x, y);
    //sprintf(filename, "%s/result.flo", posdir0);
    //WriteFlowFile(merged0, filename);
    //strcpy(in0, filename);
    
    sprintf(filename, "%s/result0-4refined2.pfm", posdir1);
    ReadImageVerb(x, filename, 0);
    sprintf(filename, "%s/result1-4refined2.pfm", posdir1);
    ReadImageVerb(y, filename, 0);
    merged1 = mergeToFloImage(x, y);
    //sprintf(filename, "%s/result.flo", posdir1);
    //WriteFlowFile(merged1, filename);
    //strcpy(in1, filename);
    
    computeDisparities(merged0, merged1, fdisp0, fdisp1, dXmin, dXmax, dYmin, dYmax);
    
    // now need to separate L(fdisp(0|1)) into u,v files corresponding to x-, y- disparities.
    // pair<CFloatImage,CFloatImage> splitFloImage(CFloatImage &merged);
    pair<CFloatImage,CFloatImage> ppos0, ppos1;
    ppos0 = splitFloImage(fdisp0);
    ppos1 = splitFloImage(fdisp1);
    CFloatImage fx0,fy0,fx1,fy1;
    fx0 = ppos0.first;
    fy0 = ppos0.second;
    fx1 = ppos1.first;
    fy1 = ppos1.second;
    
    char px0[100], py0[100], px1[100], py1[100];
    sprintf(px0, "%s/disp%d%dx.pfm", outdir0, pos0, pos1);
    sprintf(py0, "%s/disp%d%dy.pfm", outdir0, pos0, pos1);
    sprintf(px1, "%s/disp%d%dx.pfm", outdir1, pos1, pos0);
    sprintf(py1, "%s/disp%d%dy.pfm", outdir1, pos1, pos0);
    
    WriteImageVerb(fx0, px0, verbose);
    WriteImageVerb(fy0, py0, verbose);
    WriteImageVerb(fx1, px1, verbose);
    WriteImageVerb(fy1, py1, verbose);
}

//void rectifyDecoded(int nimages, char* destdir, char** matrices, char** photos);
/*
extern "C" void rectifyPFMs {
    rectifyDecoded(nimages, camera, destdir, matrices, images);
}*/
extern "C" void computeMaps(char *impath, char *intr, char *extr) {
    printf("%s\n%s\n%s\n", impath, intr, extr);
    CFloatImage im;
    ReadImage(im, impath);
    CShape sh = im.Shape();
    printf("decoded image dimensions: [%d x %d]\n", sh.width, sh.height);
    computemaps(sh.width, sh.height, intr, extr);
}
