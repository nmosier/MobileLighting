//
//  activeLighting_wrapper.cpp
//  demo
//
//  Created by Nicholas Mosier on 6/28/17.
//  Copyright © 2017 Nicholas Mosier. All rights reserved.
//

#include <stdio.h>
#include "ImgProcessor.h"

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
    CFloatImage fu0,fv0,fu1,fv1;
    fu0 = ppos0.first;
    fv0 = ppos0.second;
    fu1 = ppos1.first;
    fv1 = ppos1.second;
    
    char pu0[100], pv0[100], pu1[100], pv1[100];
    sprintf(pu0, "%s/disp%d%du.pfm", outdir0, pos0, pos1);
    sprintf(pv0, "%s/disp%d%dv.pfm", outdir0, pos0, pos1);
    sprintf(pu1, "%s/disp%d%du.pfm", outdir1, pos1, pos0);
    sprintf(pv1, "%s/disp%d%dv.pfm", outdir1, pos1, pos0);
    
    WriteImageVerb(fu0, pu0, verbose);
    WriteImageVerb(fv0, pv0, verbose);
    WriteImageVerb(fu1, pu1, verbose);
    WriteImageVerb(fv1, pv1, verbose);
}
