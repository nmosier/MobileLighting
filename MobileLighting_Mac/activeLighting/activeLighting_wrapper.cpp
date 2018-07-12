//
//  activeLighting_wrapper.cpp
//  demo
//
//  Created by Nicholas Mosier on 6/28/17.
//  Copyright © 2017 Nicholas Mosier. All rights reserved.
//

#include <stdio.h>
#include <iostream>
#include "activeLighting.h"
#include "Rectify.hpp"
#include "Utils.h"
#include "Disparities.h"
#include <assert.h>

extern "C" void refineDecodedIm(char *outdir, int direction, char* decodedIm, double angle, char *posID) {
    refine(outdir, direction, decodedIm, angle, posID);	// returns final CFloatImage, ignore
}

extern "C" void computeMaps(char *impath, char *intr, char *extr) {
    printf("%s\n%s\n%s\n", impath, intr, extr);
    CFloatImage im;
    ReadImage(im, impath);
    CShape sh = im.Shape();
    printf("decoded image dimensions: [%d x %d]\n", sh.width, sh.height);
    computemaps(sh.width, sh.height, intr, extr);
}

extern "C" void disparitiesOfRefinedImgs(char *posdir0, char *posdir1, char *outdir0, char *outdir1, int pos0, int pos1, int rectified, int dXmin, int dXmax, int dYmin, int dYmax) {
    // in0, in1 are flo images, need to create
    // so inputs should be to directories?
    int verbose = 1;
    
    CFloatImage x, y;
    CFloatImage merged0, merged1;
    CFloatImage fdisp0, fdisp1;
    char filename[1000]; //, in0[1000], in1[1000];
    
    char leftID[50], rightID[50];
    if (rectified) {
        sprintf(leftID, "%d%d", pos0, pos1);
        sprintf(rightID, "%d%d", pos0, pos1);
    } else {
        sprintf(leftID, "%d", pos0);
        sprintf(rightID, "%d", pos1);
    }
    
    // first create necessary FLO files for computeDisparities()
    sprintf(filename, "%s/result%su-4refined2.pfm", posdir0, leftID);
    ReadImageVerb(x, filename, 1);
    sprintf(filename, "%s/result%sv-4refined2.pfm", posdir0, leftID);
    ReadImageVerb(y, filename, 1);
    merged0 = mergeToFloImage(x, y);

    sprintf(filename, "%s/result%su-4refined2.pfm", posdir1, rightID);
    ReadImageVerb(x, filename, 0);
    sprintf(filename, "%s/result%sv-4refined2.pfm", posdir1, rightID);
    ReadImageVerb(y, filename, 0);
    merged1 = mergeToFloImage(x, y);

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
    sprintf(px0, "%s/disp%d%dx-0initial.pfm", outdir0, pos0, pos1);
    sprintf(py0, "%s/disp%d%dy-0initial.pfm", outdir0, pos0, pos1);
    sprintf(px1, "%s/disp%d%dx-0initial.pfm", outdir1, pos0, pos1);
    sprintf(py1, "%s/disp%d%dy-0initial.pfm", outdir1, pos0, pos1);
    
    WriteImageVerb(fx0, px0, verbose);
    WriteImageVerb(fy0, py0, verbose);
    WriteImageVerb(fx1, px1, verbose);
    WriteImageVerb(fy1, py1, verbose);
}

extern "C" void crosscheckDisparities(char *posdir0, char *posdir1, int pos0, int pos1, float thresh, int xonly, int halfocc, char *in_suffix, char *out_suffix) {
    CFloatImage x0,x1,y0,y1;
    char buffer[100];
    sprintf(buffer, "%s/disp%d%dx-%s.pfm", posdir0, pos0, pos1, in_suffix);
    ReadImageVerb(x0, buffer, 1);
    sprintf(buffer, "%s/disp%d%dx-%s.pfm", posdir1, pos0, pos1, in_suffix);
    ReadImageVerb(x1, buffer, 1);
    
    if (xonly) {
        // create blank images for ydisps
        CShape sh = x0.Shape();
        y0.ReAllocate(sh);
        y1.ReAllocate(sh);
        y0.FillPixels(UNK);
        y1.FillPixels(UNK);
    } else {
        sprintf(buffer, "%s/disp%d%dy-%s.pfm", posdir0, pos0, pos1, in_suffix);
        ReadImageVerb(y0, buffer, 1);
        sprintf(buffer, "%s/disp%d%dy-%s.pfm", posdir1, pos0, pos1, in_suffix);
        ReadImageVerb(y1, buffer, 1);
    }
    
    CFloatImage d0 = mergeToFloImage(x0, y0);
    CFloatImage d1 = mergeToFloImage(x1, y1);
    pair<CFloatImage,CFloatImage> outputs = runCrossCheck(d0, d1, thresh, xonly, halfocc);
    pair<CFloatImage,CFloatImage> crosscheck0, crosscheck1;
    crosscheck0 = splitFloImage(outputs.first);
    crosscheck1 = splitFloImage(outputs.second);
    
    CFloatImage ccx0, ccy0, ccx1, ccy1;
    ccx0 = crosscheck0.first;
    ccx1 = crosscheck1.first;
    ccy0 = crosscheck0.second;
    ccy1 = crosscheck1.second;
    
    sprintf(buffer, "%s/disp%d%dx-%s.pfm", posdir0, pos0, pos1, out_suffix);
    WriteImageVerb(ccx0, buffer, 1);
    sprintf(buffer, "%s/disp%d%dx-%s.pfm", posdir1, pos0, pos1, out_suffix);
    WriteImageVerb(ccx1, buffer, 1);
    
    if (!xonly) {
        sprintf(buffer, "%s/disp%d%dy-%s.pfm", posdir0, pos0, pos1, out_suffix);
        WriteImageVerb(ccy0, buffer, 1);
        sprintf(buffer, "%s/disp%d%dy-%s.pfm", posdir1, pos0, pos1, out_suffix);
        WriteImageVerb(ccy1, buffer, 1);
    }
}

// CFloatImage runFilter(CFloatImage img, float ythresh, int kx, int ky, int mincompsize, int maxholesize);
extern "C" void filterDisparities(char *dispx, char *dispy, char *outx, char *outy, int pos0, int pos1, float ythresh, int kx, int ky, int mincompsize, int maxholesize) {
    assert (dispx != NULL);
    assert (outx != NULL);
    
    CFloatImage x, y;
    ReadImageVerb(x, dispx, 1);
    if (dispy == NULL) {
        y.ReAllocate(x.Shape());
        y.FillPixels(INFINITY);
    } else {
        ReadImageVerb(y, dispy, 1);
    }
    CFloatImage merged = mergeToFloImage(x, y);
    
    CFloatImage mergedResult = runFilter(merged, ythresh, kx, ky, mincompsize, maxholesize);
    pair<CFloatImage,CFloatImage> imgpair = splitFloImage(mergedResult);
    x = imgpair.first;
    y = imgpair.second;
    
    WriteImageVerb(x, outx, 1);
    if (outy != NULL)
        WriteImageVerb(y, outy, 1);
}

//CFloatImage mergeDisparityMaps(CFloatImage images[], int count, int mingroup, float maxdiff)
extern "C" void mergeDisparities(char *imgsx[], char *imgsy[], char *outx, char *outy, int count, int mingroup, float maxdiff) {
    CFloatImage images[count];
    for (int i = 0; i < count; ++i) {
        CFloatImage x, y, flo;
        ReadImageVerb(x, imgsx[i], 1);
        ReadImageVerb(y, imgsy[i], 1);
        flo = mergeToFloImage(x, y);
        images[i] = flo;
    }
    CFloatImage result = mergeDisparityMaps(images, count, mingroup, maxdiff);
    pair<CFloatImage,CFloatImage> flo = splitFloImage(result);
    WriteImageVerb(flo.first, outx, 1);
    WriteImageVerb(flo.second, outy, 1);
//    WriteImageVerb(result, out, 1);
}

//CFloatImage reproject(CFloatImage dispflo, CFloatImage codeflo, char* outFile, char* errFile, char* matfile);
extern "C" void reprojectDisparities(char *dispx_file, char *dispy_file, char *codex_file, char *codey_file, char *outx_file, char *outy_file, char *err_file, char *mat_file, char *log_file) {
    CFloatImage dispx, dispy, disp;
    CFloatImage codex, codey, code;
    CFloatImage outx, outy, out;
    ReadImageVerb(dispx, dispx_file, 1);
    ReadImageVerb(dispy, dispy_file, 1);
    ReadImageVerb(codex, codex_file, 1);
    ReadImageVerb(codey, codey_file, 1);
    disp = mergeToFloImage(dispx, dispy);
    code = mergeToFloImage(codex, codey);
    
    CFloatImage floresult = reproject(disp, code, err_file, mat_file, log_file);
    pair<CFloatImage,CFloatImage> splitresult = splitFloImage(floresult);
    WriteImageVerb(splitresult.first, outx_file, 1);
    WriteImageVerb(splitresult.second, outy_file, 1);
}
