///////////////////////////////////////////////////////////////////////////
//
// NAME
//  Decode.cpp -- decodes series of stripe-coded images (now use CMU codes rather than Gray codes)
//
// DESCRIPTION
//   reads series of thresholded images (each labeled 0 (b), 128 (unknown), 255 (w))
//   and recovers bit pattern at each pixel.  
//
//
// Copyright � Daniel Scharstein, 2002.
//
// modified 12/2013 and 1/2014 to do better filtering and code refining
//
///////////////////////////////////////////////////////////////////////////

#include <math.h>
#include "imageLib.h"
#include <iostream>
#include <fstream>
#include "Utils.h"

#define MAXCODES 1024

int pixelToCode[MAXCODES];
int codeToPixel[MAXCODES];

void test(void) {
	printf("Decode.cpp: IT WORKED.\n");
}

// load code file
void loadCodes(char* file){
    int ncodes;
    ifstream in(file, ios::binary | ios::in);
    if (! in.is_open())
	throw CError("cannot open file %s\n", file);

    in.read((char*)&ncodes, 4);
    if (ncodes > MAXCODES)
	throw CError("too many codes\n");

    for (int i = 0; i < ncodes; i++) {
	in.read((char*)&pixelToCode[i], 4);
    }
    for (int i =0 ; i < ncodes; i++) {
	in.read((char*)&codeToPixel[i], 4);
    }
}

// store image 'im' as k-th bit in 'val'  (k==0 means least-significant bit)
// if a pixel in 'im' has label 128 (unknown), mark corresponding pixel in 'unk'
void store_bit(CByteImage im, CIntImage val, CIntImage unk, int k)
{
    CShape sh = im.Shape();
    int x, y, w = sh.width, h = sh.height;

    unsigned int bit = (1 << k);
    for (y = 0; y < h; y++) {
        uchar *p = (uchar *)&im.Pixel(0, y, 0);
        unsigned int *v = (unsigned int *)&val.Pixel(0, y, 0);
        unsigned int *u = (unsigned int *)&unk.Pixel(0, y, 0);

        for (x = 0; x < w; x++) {
	    if (p[x] == 255)
		v[x] |= bit;
	    else if (p[x] == 128)
		u[x] |= bit;
	}
    }
}

// decode binary codes.  val contains the code, unk contains the set of unknown bits.
// TODO: could be smarter here by trying to disambiguate pixels where only one bit is 
// uncertain
void decodeCode(CIntImage val, CIntImage unk, CFloatImage &result)
{
    CShape sh = val.Shape();
    result.ReAllocate(sh);

    int x, y, w = sh.width, h = sh.height;
	
    for (y = 0; y < h; y++) {
	int *v = (int *)&val.Pixel(0, y, 0);
	int *u = (int *)&unk.Pixel(0, y, 0);
	float *r = (float *)&result.Pixel(0, y, 0);
	for (x = 0; x < w; x++) {
	    if (u[x] == 0)
		r[x] = codeToPixel[v[x]];
	    else
		r[x] = UNK; // uncertain pixel
	}
    }
}


// fill holes in a line of code map
void fillCodeHolesLine(float *val, int stride, int n, int maxwidth, int maxborderdiff)
{	
    float oldv = UNK;
    int cnt = 0;
    int hole = 0;
    for (int x = 0; x < n; x++, val += stride) {
	float v = *val;
	if (v != UNK) {
	    if (hole) {
		if (cnt <= maxwidth && fabs(v - oldv) <= maxborderdiff) {
		    float fillv = (v + oldv) / 2.0;
		    for (int k = 1; k <= cnt; k++)
			val[-k * stride] = fillv;
		}
	    }
	    cnt = 0;
	    oldv = v;
	    hole = 0;
	} else {
	    hole = 1;
	    cnt++;
	}
    }
}

// fill holes in code map. if directon==0, in x direction, else in y direction
void fillCodeHoles(CFloatImage im0, int maxwidth, float maxborderdiff, int direction)
{
    CShape sh = im0.Shape();
    int x, y, w = sh.width, h = sh.height;
    int stride;

    if (direction==0) { // x direction
	stride = 1;
	for (y = 0; y < h; y++) {
	    float *val = &im0.Pixel(0, y, 0);
	    fillCodeHolesLine(val, stride, w, maxwidth, maxborderdiff);
	}
    } else { // y direction
        stride = &im0.Pixel(0, 1, 0) - &im0.Pixel(0, 0, 0);
	for (x = 0; x < w; x++) {
	    float *val = &im0.Pixel(x, 0, 0);
	    fillCodeHolesLine(val, stride, h, maxwidth, maxborderdiff);
	}
    }
}



// refine codes using a running average over window of width 2*rad+1
// maxgrad is maximal gradient of values
// 1/21/2014: tried using weighted average based on distance (i.e. "tent filter" rather than box filter)
// not sure it produces less staircasing, but it probably does overall less blurring
void refineCodesLine(float *v, float *f, int stride, int n0, int rad, float maxgrad) //, int debugy)
{	
    int minsupport = rad;   // how many "good" values are needed to trust the average

    int n = n0 * stride;
    for (int x0 = 0; x0 < n0; x0++) {
        int x = x0 * stride;
        float sum = 0;
        float sumw = 0;
		int cnt = 0;
        float v0 = v[x];
        f[x] = v0;
        if (v0 == UNK)
            continue;
		//int debug = 0;//(debugy > 0) && ((x0 >= 996) && (x0 <= 999));
		//if (debug)
		//printf("x=%d, y=%d, v0 = %.2f\n", x0, debugy, v0);
        // compare pixels over window to v0 and include in average if close enough
        for (int r0 = -rad; r0 <= rad; r0++) {
            int r = r0 * stride;
            int x1 = x + r;
	 	   //float v1 = v[x1];
            int mirror = 0;
            float maxdiff = fabs(r0) * maxgrad + 1;
	    	float w = 1.0  - (fabs(r0) / (rad + 1.0));
	 	   //float w = 1.0; // old (original) box filter
	 	   //float diff = fabs(v0 - v1);
	 	   //if (debug)
	 	   //printf("r0=%5d, v1=%.2f, w=%.2f, diff=%.2f, maxdiff=%.2f: ", r0, v1, w, diff, maxdiff);
            // if out of bounds, or unknown value, or difference too big, try mirrored
            if (x1 < 0 || x1 >= n || fabs(v0 - v[x1]) > maxdiff || v[x1] == UNK) {
                x1 = x - r;
                mirror = 1;
            }
            // if (now) out of bounds or (still) unknown or differnce too big, don't use
            if (x1 < 0 || x1 >= n || fabs(v0 - v[x1]) > maxdiff || v[x1] == UNK) {
				//if (debug)
				//printf("skip\n");
                continue;
	    	}
            // close enough: add difference to center value (subtract if x was mirrored)
		    float vv = (mirror ? (v0 - v[x1]) : (v[x1] - v0));
		    //if (debug)
		    //printf("vv=%.2f\n", vv);
            sum += w * vv;
	   		sumw += w;
            cnt++;
        }
        if (cnt >= minsupport) {
            f[x] = v0 + sum/sumw;    // result is center value plus average of diffs
	    //if (debug)
	    //printf("sum=%.2f, sumw=%.2f, result=%.2f\n", sum, sumw, f[x]);
	}
    }
}


// refine codes using a running average over window of width 2*rad+1
void refineCodes(CFloatImage val, CFloatImage &fval, int rad, float maxgrad, int direction)
{
    CShape sh = val.Shape();
    fval.ReAllocate(sh);
    int x, y, w = sh.width, h = sh.height;

    if (direction == 0) {
    	for (y = 0; y < h; y++) {
	    float *v = &val.Pixel(0, y, 0);
	    float *f = &fval.Pixel(0, y, 0);
            int stride = &val.Pixel(1, 0, 0) - &val.Pixel(0, 0, 0);
            // assume that f has same stride!
	    //int debugy = (y == 617) ? y : 0;
            refineCodesLine(v, f, stride, w, rad, maxgrad); //, debugy);
        }
    } else {
    	for (x = 0; x < w; x++) {
	    float *v = &val.Pixel(x, 0, 0);
	    float *f = &fval.Pixel(x, 0, 0);
            int stride = &val.Pixel(0, 1, 0) - &val.Pixel(0, 0, 0);
            // assume that f has same stride!
	    //int debugy = (x == 998) ? x : 0;
            refineCodesLine(v, f, stride, h, rad, maxgrad); //, debugy);
        }
    }
}


// map float code values to color map
void fval2rgb(int N, CFloatImage val, CByteImage &result)
{
    CShape sh = val.Shape();
    sh.nBands = 3;
    result.ReAllocate(sh);

    int x, y, w = sh.width, h = sh.height;
	
    float scale = 1.0/(1<<N);
    for (y = 0; y < h; y++) {
	float *v = &val.Pixel(0, y, 0);
	uchar *r = &result.Pixel(0, y, 0);
		
	for (x = 0; x < w; x++) {
	    if (v[x] == UNK) {
		r[3*x] = r[3*x+1] = r[3*x+2] = 0;
	    } else {
		float c = v[x];
		float f = c * scale;
		hueshade(f, &r[3*x]);
	    }
	}
    }
}



// new filter with different idea: require certain fraction (1/4?) of pixels with almost identical 
// code (+/- maxdiff) in window.  should better filter out isolated pixels.
// DS 11/25/2013
void filter(CFloatImage val, int radius, float fraction, float maxdiff)
{
    CShape sh = val.Shape();
    int w = sh.width, h = sh.height;
    CFloatImage tmp;
    tmp.ReAllocate(sh);
    int nfiltered = 0;

    for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
            float p0 = val.Pixel(x, y, 0);
	    tmp.Pixel(x, y, 0) = p0;
            if (p0 == UNK)
		continue;
	    int cnt = 0;
	    int total = 0;
	    for (int py = y-radius; py <= y+radius; py++) {
		if (py < 0 || py >= h)
		    continue;
		for (int px = x-radius; px <= x+radius; px++) {
		    if (px < 0 || px >= w)
			continue;
		    if (px == x && py == y)
			continue;
		    float pp = val.Pixel(px, py, 0);
		    if (pp != UNK) {
			total++;
			if (fabs(pp-p0) <= maxdiff)
			    cnt++;
		    }
		}
	    }
	    // require certain fraction (0.25 ?) of non-UNK values in window to be within maxdiff
	    // also require at least 3 pixels total
	    if (cnt < fraction * total || cnt < 3) {
		tmp.Pixel(x, y, 0) = UNK; 
		nfiltered ++;
	    }
	}	
    }
    for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
            val.Pixel(x, y, 0) = tmp.Pixel(x, y, 0);
        }
    }
    printf("%d pixels filtered (%.3f%%)\n", nfiltered, (float)nfiltered * 100.0 / (w * h));
}

//erases foreground object from fval
void foregroundErase(CFloatImage fval, CByteImage mask) 
{
    CShape sh = fval.Shape();
    int w = sh.width, h = sh.height;
    CShape sh2 = mask.Shape();
    int w2 = sh2.width, h2 = sh2.height;
    if (w == w2 && h == h2){
	for (int y = 0; y < h; y++) {
	    for (int x = 0; x < w; x++) {
		if (mask.Pixel(x, y, 0) == 0)
		    fval.Pixel(x, y, 0) = UNK;
	    }
	}
    }
}


// Decode images.  if direction==0, code goes (mainly) in x direction, otherwise in y-direction
// 1. combine all numIm thresholded images into CIntImages val and unk
// 2. decode binary codes (considering unk) into val
// 3. fill holes in val
// 4. refine code values into float values fval
CFloatImage decode(char* outdir, char* codefile, int direction, int eraseForeground, char* maskdir, char **imList, int numIm)
{
    CByteImage im;
    CShape sh;
    int i, verbose=1;
    char filename[1000];
    CIntImage val, unk;
    CFloatImage fval, fval1, fval2;
    
    loadCodes(codefile);

	
    if (numIm > 0) {
   
	// combine all numIm thresholded images into CIntImages val and unk
	// for both x and y directions
	for (i = 0; i < numIm; i++) {
	    ReadImageVerb(im, imList[i], verbose);
	    if (i == 0) {
		sh = im.Shape();
		val.ReAllocate(sh, true);
		val.ClearPixels();
		unk.ReAllocate(sh, true);
		unk.ClearPixels();
	    }
	    if (sh != im.Shape() || sh.nBands != 1)
		throw CError("decode: all images need to have same size and 1 band");
	    
	    store_bit(im, val, unk, i);
	}
	

	// decode binary code (considering unk) into val
	
	decodeCode(val, unk, fval);

	// save original decoded image
	sprintf(filename, "%s/result%d-0initial.pfm", outdir, direction);
	WriteImageVerb(fval, filename, verbose);
    
    } else { // if no images are given, reload initial result and rerun subsequent processing steps

	sprintf(filename, "%s/result%d-0initial.pfm", outdir, direction);
	ReadImageVerb(fval, filename, verbose);

    }
    
    
    // fval is float

    // filter to remove isolated pixels with different code values
    if (1) {
	int rad = 4;
	float fraction = 0.25;
	float maxdiff = 4.0;
	printf("Filtering image with radius %d, fraction %g, and maxdiff %g\n", rad, fraction, maxdiff);
	filter(fval, rad, fraction, maxdiff);
    }	
	
    if (1) { // save filtered image
	sprintf(filename, "%s/result%d-1filtered.pfm", outdir, direction);
	WriteImageVerb(fval, filename, verbose);
    }

    if (1) {
	// fill holes
	if (verbose) printf("filling holes\n");
	//int maxwidth = 7; // since higher resolution, try filling larger holes
	int maxwidth = 5; // nope, back to 5 pixels, seems to be a good compromise
	float maxborderdiff = 2; // still sometimes need 2, e.g. Newkuba/P4 on the lamp
	fillCodeHoles(fval, maxwidth, maxborderdiff, direction);
	maxborderdiff = 0;
	fillCodeHoles(fval, maxwidth, maxborderdiff, 1-direction);
	maxborderdiff = 1;
	fillCodeHoles(fval, maxwidth, maxborderdiff, direction);
    }

    if (1) { // save hole-filled image
	sprintf(filename, "%s/result%d-2holefilled.pfm", outdir, direction);
	WriteImageVerb(fval, filename, verbose);
    }

    // refine code values
    if (verbose) printf("refining code values\n");
    //int radius = 3;
    int radius = 7;// try larger radius since higher resolution
    int maxgrad0 = 1.0; // expected maximum gradient of code values per pixel in code direction
    int maxgrad1 = 0.1; // expected maximum gradient of code values per pixel in perpendicular direction
    refineCodes(fval,  fval1, radius, maxgrad0, direction);
    refineCodes(fval1, fval2, radius, maxgrad1, 1 - direction); // also refine in perpendicular direction


    if (1) { // save refined image
	sprintf(filename, "%s/result%d-3refined1.pfm", outdir, direction);
	WriteImageVerb(fval1, filename, verbose);
	sprintf(filename, "%s/result%d-4refined2.pfm", outdir, direction);
	WriteImageVerb(fval2, filename, verbose);
    }


    // optionally erase foreground pixels
    // TODO: if I really use this, probably should do before holefilling and refining
    if (eraseForeground == 1) {
	printf("Erasing foreground pixels from background-only images\n");
        CByteImage mask;
        ReadImageVerb(mask, maskdir, verbose);
	foregroundErase(fval2, mask);	
	sprintf(filename, "%s/result%d-5foregroundremoved.pfm", outdir, direction);
	WriteImageVerb(fval2, filename, verbose);
    }


    if (0) { // don't need anymore now that I can view pfms in color
	fprintf(stderr, "encoding in ppm:\n");
	CByteImage result;

	fval2rgb(numIm, fval, result);
	sprintf(filename, "%s/cresult%da.ppm", outdir,direction);
	WriteImageVerb(result, filename, verbose);

	fval2rgb(numIm, fval1, result);
	sprintf(filename, "%s/cresult%db.ppm", outdir,direction);
	WriteImageVerb(result, filename, verbose);

	fval2rgb(numIm, fval2, result);
	sprintf(filename, "%s/cresult%dc.ppm", outdir,direction);
	WriteImageVerb(result, filename, verbose);
    }



    // save .pgm file that contains grey-level encoding of refined code values
    //if (0) { // pgm
    //fprintf(stderr, "encoding in pgm - ");
    //sh.nBands = 1;
    //CByteImage result(sh);
    //int mode = 1; // 0 - use fixed scaling, 3 - use val*4 modulo 256
    //fval2byte(fval2, result, mode);
    //sprintf(filename, "%s/result%d.pgm", outdir, direction);
    //WriteImageVerb(result, filename, verbose);
    //}

    return fval2;

}

// *** MobileLighting (Mac) currently calls this to do post-decoding refinement ***
CFloatImage refine(char *outdir, int direction, char* decodedIm) {
	CFloatImage fval, fval1, fval2;
	CShape sh;
	int i, verbose = 1;
	char filename[1000];
	
	// read in PFM
	ReadImageVerb(fval, decodedIm, verbose);
	
	// FILTER
	// filter to remove isolated pixels with different code values
    if (1) {
	int rad = 4;
	float fraction = 0.25;
	float maxdiff = 4.0;
	printf("Filtering image with radius %d, fraction %g, and maxdiff %g\n", rad, fraction, maxdiff);
	filter(fval, rad, fraction, maxdiff);
    }	
	
    if (1) { // save filtered image
	sprintf(filename, "%s/result%d-1filtered.pfm", outdir, direction);
	WriteImageVerb(fval, filename, verbose);
    }
	
	// FILL CODE HOLES
	if (1) {
	if (verbose) printf("filling holes\n");
	//int maxwidth = 7; // since higher resolution, try filling larger holes
	int maxwidth = 5; // nope, back to 5 pixels, seems to be a good compromise
	float maxborderdiff = 2; // still sometimes need 2, e.g. Newkuba/P4 on the lamp
	fillCodeHoles(fval, maxwidth, maxborderdiff, direction);
	maxborderdiff = 0;
	fillCodeHoles(fval, maxwidth, maxborderdiff, 1-direction);
	maxborderdiff = 1;
	fillCodeHoles(fval, maxwidth, maxborderdiff, direction);
    }

    if (1) { // save hole-filled image
	sprintf(filename, "%s/result%d-2holefilled.pfm", outdir, direction);
	WriteImageVerb(fval, filename, verbose);
    }
	
	// REFINE CODES
	if (verbose) printf("refining code values\n");
    //int radius = 3;
    int radius = 7;// try larger radius since higher resolution
    int maxgrad0 = 1.0; // expected maximum gradient of code values per pixel in code direction
    int maxgrad1 = 0.1; // expected maximum gradient of code values per pixel in perpendicular direction
    refineCodes(fval,  fval1, radius, maxgrad0, direction);
    refineCodes(fval1, fval2, radius, maxgrad1, 1 - direction); // also refine in perpendicular direction


    if (1) { // save refined image
	sprintf(filename, "%s/result%d-3refined1.pfm", outdir, direction);
	WriteImageVerb(fval1, filename, verbose);
	sprintf(filename, "%s/result%d-4refined2.pfm", outdir, direction);
	WriteImageVerb(fval2, filename, verbose);
    }
	
	return fval2;
}


////////////////////////////////////////////////////////////////////////////////////
// old code, no longer needed

/* -------------

#define IUNK -9999	// label for unknown pixel in Int image

// map integer code values to float
void val2float(CIntImage val, CFloatImage &fval)
{
    CShape sh = val.Shape();
    int x, y, w = sh.width, h = sh.height;
    fval.ReAllocate(sh);
	
    for (y = 0; y < h; y++) {
	int *v = &val.Pixel(0, y, 0);
	float *r = &fval.Pixel(0, y, 0);
		
	for (x = 0; x < w; x++) {
	    if (v[x] == IUNK)
		r[x] = UNK; // label for unknown pixels
	    else
		r[x] = v[x];
	}
    }
}

void iWriteImageVerb(CIntImage val, char *filename, int verbose)
{
    CFloatImage fval;
    val2float(val, fval);
    WriteImageVerb(fval, filename, verbose);
}





// map integer code values to color map
void val2rgb(int N, CIntImage val, CByteImage result)
{
    CShape sh = val.Shape();
    int x, y, w = sh.width, h = sh.height;
	
    float scale = 1.0/(1<<N);
    for (y = 0; y < h; y++) {
	int *v = &val.Pixel(0, y, 0);
	uchar *r = &result.Pixel(0, y, 0);
		
	for (x = 0; x < w; x++) {
	    if (v[x] == IUNK) {
		r[3*x] = r[3*x+1] = r[3*x+2] = 0;
	    } else {
		unsigned int c = v[x];
		float f = c * scale;
		hueshade(f, &r[3*x]);
	    }
	}
    }
}



// not sure what this code was used for anymore...
// subtract average plane from code values, by looking at pixel grid 'step' apart
void subtractPlane(CIntImage val, int step)
{
    CShape sh = val.Shape();
    int x, y, w = sh.width, h = sh.height;
    float ax, ay, b;
	
    // old code: estimate ax, ay separately using two line fits
	
    // estimate horizontal slope in center of image
    //int *xline = &val.Pixel(0, h/2, 0);
    //int xstride = &val.Pixel(1, 0, 0) - &val.Pixel(0, 0, 0);
    //fitLine(xline, w, xstride, ax, b, IUNK);
    //printf("horizontal line: a=%g, b=%g\n", ax, b);
	  
    // estimate vertical slope in center of image
    //int *yline = &val.Pixel(w/2, 0, 0);
    //int ystride = &val.Pixel(0, 1, 0) - &val.Pixel(0, 0, 0);
    //fitLine(yline, h, ystride, ay, b, IUNK);
    //printf("vertical line: a=%g, b=%g\n", ay, b);
    //b = 0; // don't need b here

    int *data = &val.Pixel(0, 0, 0);
    int xstride = &val.Pixel(1, 0, 0) - &val.Pixel(0, 0, 0);
    int ystride = &val.Pixel(0, 1, 0) - &val.Pixel(0, 0, 0);
    fitPlane(data, w, h, step, step, xstride, ystride, ax, ay, b, IUNK);
    //printf("plane params: ax=%g, ay=%g, b=%g\n", ax, ay, b);

    // subtract average plane
    for (y = 0; y < h; y++) {
	int *v = &val.Pixel(0, y, 0);
	for (x = 0; x < w; x++) {
	    if (v[x] != IUNK) {
		float vf = v[x];
		vf -= ax * x + ay * y + b;	// subtract plane
		if (vf == IUNK)
		    vf += 0.001f;	// make sure we're not introducing IUNK by accident
		v[x] = vf;
	    }
	}
    }
}


// old filter by York
//Surveys the image and finds pixels that are too bright compared to other
//pixels around them and changes them to IUNK
// prints total number of pixels filtered
void filter2(CIntImage val, int radius, int maxDiff) 
{
    CShape sh = val.Shape();
    int w = sh.width, h = sh.height, nB = sh.nBands;
    CIntImage tmp;
    CShape sh2(w, h, nB);
    tmp.ReAllocate(sh2);
    int nfiltered = 0;
    
    for (int y = 0; y < h; y++) {
	for (int x = 0; x < w; x++) {
	    int r0 = val.Pixel(x, y, 0);
	    if (r0 != IUNK) {
		int cnt = 0;
		int avg = 0;
		int unk = 0;
		int total = 0;
		for (int px = x-radius; px <= x+radius; px++) {
		    for (int py = y-radius; py <= y+radius; py++) {
			if (px >= 0 && py >= 0 && px < w && py < h) {
			    if (px == x && py == y){
				continue;
			    }
			    else {
				if (val.Pixel(px, py, 0) == IUNK) {
				    unk++;
				}
				else {
				    total = total+val.Pixel(px, py, 0);
				}
				cnt++;
			    }
			}
		    }
		}
		int denom = abs(cnt-unk);
		if (denom != 0)
		    avg = total/denom;
		else 
		    avg = total/cnt;
		if (abs(avg-r0) > maxDiff) {
		    tmp.Pixel(x, y, 0) = IUNK; 
		    nfiltered ++;
		}
		else
		    tmp.Pixel(x, y, 0) = r0;
	    }	
	}
    }
    for (int y = 0; y < h; y++) {
	for (int x = 0; x < w; x++) {
	    val.Pixel(x, y, 0) = tmp.Pixel(x, y, 0);
	}
    }
    printf("%d pixels filtered (%.3f%%)\n", nfiltered, (float)nfiltered * 100.0 / (w * h));
}



// map float codes to grey image by scaling and clipping to 0..255
// if mode == 0, use FIXEDMIN, FIXEDMAX
// if mode == 1, use actual min, actual max
// if mode == 2, use min = mean - FACT * stddev, max = mean + FACT * stddev
// if mode == 3, use values * 4 modulo 256
void fval2byte(CFloatImage fval, CByteImage result, int mode) 
{
    float FIXEDMIN = 200;
    float FIXEDMAX = 900;
    float FACT = 0.5;

    CShape sh = fval.Shape();
    int x, y, w = sh.width, h = sh.height;
    float minv, maxv;

    if (mode == 0 || mode == 3) {
	minv = FIXEDMIN;
	maxv = FIXEDMAX;
    } else {
	// compute min, max, mean and stddev
	minv = 1e20f;
	maxv = -1e20f;
	int s1 = 0;
	float sv = 0;
	float svv = 0;
	for (y = 0; y < h; y++) {
	    float *v = &fval.Pixel(0, y, 0);
	    for (x = 0; x < w; x++) {
		float v0 = v[x];
		if (v0 == UNK) 
		    continue;
		s1++;
		sv += v0;
		svv += v0*v0;
		minv = __min(minv, v0);
		maxv = __max(maxv, v0);
	    }
	}
	if (mode == 2) { // use mean +/- FACT * stddev
	    float mean = sv / s1;
	    float var = svv / s1 - 2 * mean + (mean * mean);
	    float stddev = sqrt(var);
	    //printf("mean = %g, stddev = %g\n", mean, stddev);
	    //printf("    min = %g, max = %g\n", minv, maxv);
	    minv = __max(minv, mean - FACT * stddev);
	    maxv = __min(maxv, mean + FACT * stddev);
	}
    }

    if (mode < 3)
    	printf("min = %g, max = %g\n", minv, maxv);
    else
        printf("mapping * 4 modulo 256\n");

    // map to 0..255
    for (y = 0; y < h; y++) {
	float *v = &fval.Pixel(0, y, 0);
	uchar *r = &result.Pixel(0, y, 0);
	for (x = 0; x < w; x++) {
	    if (v[x] == UNK)
		//??? if (v[x] < 0 ) // CHANGED to make compatible with old code -1==UNK
		r[x] = 0;
	    else {
		if (mode==3)
		    r[x] = ((int)(v[x]*4 + 0.5)) % 256;
		else
		    r[x] = __min(255, __max(0, (v[x] - minv) * 255 / (maxv - minv)));
	    }
	}
    }
}
 

------------------ 
*/
