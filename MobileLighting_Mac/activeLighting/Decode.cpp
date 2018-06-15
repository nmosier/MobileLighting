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
// modified 5/2018 and 6/2018 by Nicholas Mosier to use smarter refinement
///////////////////////////////////////////////////////////////////////////

#include <math.h>
#include "imageLib.h"
#include <iostream>
#include <fstream>
#include "Utils.h"
#include "Debug.h"

#define MAXCODES 1024

int pixelToCode[MAXCODES];
int codeToPixel[MAXCODES];

// load code file
/*
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
*/
// store image 'im' as k-th bit in 'val'  (k==0 means least-significant bit)
// if a pixel in 'im' has label 128 (unknown), mark corresponding pixel in 'unk'
/*
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
*/
/*
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

*/

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

// refine codes using a planar fitting approach
// created by Nicholas Mosier, 06/05/2018
void refineCodesPlanePixel(CFloatImage val, CFloatImage &fval, int x0, int y0, int rad, float maxdiff, int minsupport)
{
	CShape sh = val.Shape();
	int w = sh.width, h = sh.height;
	vector<float> vx, vy, vz;
	float v = val.Pixel(x0,y0,0);		// center input pixel
	float *f = &fval.Pixel(x0,y0,0);	// output pixel
	
	int x, y;
	for (x = max(x0-rad,0); x <= min(x0+rad,w-1); ++x) {
		for (y = max(y0-rad,0); y <= min(y0+rad,h-1); ++y) {
			// (x,y) guaranteed to be w/i bounds
			float zval = val.Pixel(x,y,0);
			if (zval != UNK) {
				vx.push_back(x-x0);
				vy.push_back(y-y0);
				vz.push_back(zval);
			}
		}
	}
	
	float a,b,c;	// constants for fitted plane z = ax + by + c
	fitPlane(vx, vy, vz, a, b, c);
	
	int cnt = 0;
	for (int i = 0; i < vz.size(); ++i) {
		if (fabs(vz[i] - (a*vx[i] + b*vy[i] + c)) <= maxdiff) {
			++cnt;
		}
	}
	
	if (cnt >= minsupport) {	// check if enough pixels had known values
		*f = c;
	} else {
		*f = v;
	}
}

// refine codes using angle of prominent stripe direction
// - mode: determines refinement algorithm to use
void refineCodes(CFloatImage val, CFloatImage &fval, int rad, float maxgrad, double angle)
{
    CShape sh = val.Shape();
    fval.ReAllocate(sh);
    int x, y, w = sh.width, h = sh.height;
	
	switch (refine_mode) {
	case refine_old:
	{
		double dx, dy;
		dx = cos(angle);
		dy = sin(angle);
		int direction;
		if (fabs(dx) >= fabs(dy))
			direction = 0;
		else
			direction = 1;
		
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
		break;
	}
    case refine_angle:
    {
	    int dx = round(cos(angle)), dy = round(sin(angle));
	    if (dy < 0) {	// ensures stride is a positive number
			dx = -dx;
			dy = -dy;
		}
		
		int stride;
		float *v, *f;
		if (dx == 1 && dy == 0) {
			stride = &val.Pixel(1, 0, 0) - &val.Pixel(0, 0, 0);
			for (y = 0; y < h; ++y) {
				v = &val.Pixel(0, y, 0);
				f = &fval.Pixel(0, y, 0);
				refineCodesLine(v, f, stride, w, rad, maxgrad);
			}	
		} else if (dx == 0 && dy == 1) {
			stride = &val.Pixel(0, 1, 0) - &val.Pixel(0, 0, 0);
			for (x = 0; x < w; ++x) {
				v = &val.Pixel(x, 0, 0);
				f = &fval.Pixel(x, 0, 0);
				refineCodesLine(v, f, stride, h, rad, maxgrad);
			}
		} else if (dx == 1 && dy == 1) {
			int rad_adj = round(rad / sqrt(2));	// adjust rad & maxgrad, since compared pixels are now sqrt(2) distance apart
			float maxgrad_adj = maxgrad * 2;//sqrt(2);
			stride = &val.Pixel(1, 1, 0) - &val.Pixel(0, 0, 0);
			for (x = 0; x < w; ++x) {
				v = &val.Pixel(x, 0, 0);
				f = &fval.Pixel(x, 0, 0);
				int n = min(w-x, h);	// the maximum number of windows (center pixels) to consider
				refineCodesLine(v, f, stride, n, rad_adj, maxgrad_adj);
			}
			for (y = 1; y < h; ++y) {		// don't count (0,0) twice
				v = &val.Pixel(0, y, 0);
				f = &fval.Pixel(0, y, 0);
				int n = min(w, h-y);
				refineCodesLine(v, f, stride, n, rad_adj, maxgrad_adj);
			}
		} else if (dx == -1 && dy == 1) {
			int rad_adj = round(rad / sqrt(2));	// adjust rad & maxgrad, since compared pixels are now sqrt(2) distance apart
			float maxgrad_adj = maxgrad * 2; //sqrt(2);
			stride = &val.Pixel(0, 1, 0) - &val.Pixel(1, 0, 0);
			for (x = 0; x < w; ++x) {
				v = &val.Pixel(x, 0, 0);
				f = &fval.Pixel(x, 0, 0);
				int n = min(x+1, h);	// the maximum number of windows (center pixels) to consider
				refineCodesLine(v, f, stride, n, rad_adj, maxgrad_adj);
			}
			for (y = 1; y < h; ++y) {
				//printf("refining line %d\n", y);
				v = &val.Pixel(w-1, y, 0);
				f = &fval.Pixel(w-1, y, 0);
				int n = min(w, h-y);
				refineCodesLine(v, f, stride, n, rad_adj, maxgrad_adj);
			}
		} else {
			char error[100];
			sprintf(error, "refine: unsupported direction (%d, %d)", dx, dy);
			throw CError(error);
		}
		break;
	}
	case refine_planar:
	{
		// refine_plane_windowsize is height & width of window
		int rad = (refine_plane_windowsize-1)/2;
		float maxdiff = refine_plane_maxdiff;
		int minsupport = refine_plane_minsupport;
		for (x = 0; x < w; ++x) {
			for (y = 0; y < h; ++y) {
				refineCodesPlanePixel(val, fval, x, y, rad, maxdiff, minsupport);
			}
		}
		break;
	}
	default:
	{
		char error[100];
		sprintf(error, "refine: unrecognized refinement mode");
		throw CError(error);
	}
	}
	return;
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


// *** MobileLighting (Mac) currently calls this to do post-decoding refinement ***
CFloatImage refine(char *outdir, int direction, char* decodedIm, double angle) {
	CFloatImage fval, fval1, fval2;
	CShape sh;
	int verbose = 1;
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
    refineCodes(fval,  fval1, radius, maxgrad0, angle);
    refineCodes(fval1, fval2, radius, maxgrad1, M_PI/2.0 - angle); // also refine in perpendicular direction


    if (1) { // save refined image
	sprintf(filename, "%s/result%d-3refined1.pfm", outdir, direction);
	WriteImageVerb(fval1, filename, verbose);
	sprintf(filename, "%s/result%d-4refined2.pfm", outdir, direction);
	WriteImageVerb(fval2, filename, verbose);
    }
	
	return fval2;
}
