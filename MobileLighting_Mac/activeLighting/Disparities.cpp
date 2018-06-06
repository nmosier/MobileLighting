///////////////////////////////////////////////////////////////////////////
//
// NAME
//  Disparities.cpp -- compute disparity maps
//
// DESCRIPTION
//  Compute pair of disparity maps from pair of labeled (flo) images.
//  Main functions:
//  1. computes initial disparity maps from pair of code images
//  2. combine arbitrary numbers of disparity maps
//  3. fills holes and cross-checks pair of disparity maps
//  (SolveProjection is then used to create disparity maps from illumination)
//
// Copyright � Daniel Scharstein, 2011.
//
// updated 1/14/2014 to compute matches with subpixel precision
//
///////////////////////////////////////////////////////////////////////////

#include <math.h>
#include <algorithm>
#include "imageLib.h"
#include "Utils.h"
#include "flowIO.h"
#include "assert.h"


// Cross checking

// bilinear interpolation.  vr is the nearest-neighbor value at the rounded location
float linearInterp(float fx, float fy, float vr, float v00, float v01, float v10, float v11)
{
    if (vr == UNK)
	return UNK;

    // replace UNK's with vr
    if (v00 == UNK) v00 = vr;
    if (v01 == UNK) v01 = vr;
    if (v10 == UNK) v10 = vr;
    if (v11 == UNK) v00 = vr;
    
    float w00 = (1-fx)*(1-fy);
    float w01 = (1-fx)*fy;
    float w10 = fx*(1-fy);
    float w11 = fx*fy;

    return w00 * v00 + w01 * v01 + w10 * v10 + w11 * v11;
}



// new cross-checking code, DS 1/15/2014
// added linear interpolation 1/28/2014
// input: 
//  flo images im0, im1
//  thresh -- allowable Euclidean distance of forward and backward flow vectors (usually 0.5)
//  xonly  -- whether to ignore ydisps
//  halfocc -- whether to allow half occlusions (assumes xonly==1), and pixels mapping out of bounds or on UNK
//   if halfocc == -1 (L -> R), allow half occlusion where d0 < d1 and also where d1 is UNK
//   if halfocc ==  1 (R -> L), allow half occlusion where d0 > d1 and also where d1 is UNK
CFloatImage floatCrossCheck(CFloatImage im0, CFloatImage im1, float thresh, int xonly, int halfocc)
{
    CShape sh = im0.Shape();
    CFloatImage out(sh);
    int w = sh.width, h = sh.height;

    for(int y = 0; y < h; y++){
	for(int x = 0; x < w; x++){
	    // fail cross checking by default
	    out.Pixel(x, y, 0) = UNK;
	    if (! xonly)
		out.Pixel(x, y, 1) = UNK;

	    float dx0 = im0.Pixel(x, y, 0);
	    float dy0 = im0.Pixel(x, y, 1);
	    float dy0orig = dy0;

	    if (dx0 == UNK)
		continue;
	    if (xonly || dy0 == UNK)
		dy0 = 0; // if only y component is unknown, assume 0

	    float xx = x + dx0;
	    float yy = y + dy0;

	    int ixr = (int)round(xx);
	    int iyr = (int)round(yy);

	    if (ixr < 0 || ixr >= w || iyr < 0 || iyr >= h) {
		if (halfocc != 0) { // out of bounds counts as half-occlusion, so crosschecking succeeds:
		    out.Pixel(x, y, 0) = dx0;
		}
		continue;
	    }

	    int ix0 = max(0, (int)floor(xx));
	    int iy0 = max(0, (int)floor(yy));
	    int ix1 = min(w-1, ix0 + 1);
	    int iy1 = min(h-1, iy0 + 1);

	    float fx = xx - ix0;
	    float fy = yy - iy0;

	    //fx = round(fx); // should produce original non-interpolated (nearest-neighbor) results
	    //fy = round(fy);

	    float dx1i = im1.Pixel(ixr, iyr, 0); // nearest neighbor
	    float dy1i = im1.Pixel(ixr, iyr, 1);

	    float dx1 = linearInterp(fx, fy, dx1i, 
				     im1.Pixel(ix0, iy0, 0),
				     im1.Pixel(ix0, iy1, 0),
				     im1.Pixel(ix1, iy0, 0),
				     im1.Pixel(ix1, iy1, 0));
	    float dy1 = linearInterp(fx, fy, dy1i,
				     im1.Pixel(ix0, iy0, 1),
				     im1.Pixel(ix0, iy1, 1),
				     im1.Pixel(ix1, iy0, 1),
				     im1.Pixel(ix1, iy1, 1));
	    
	    if (dx1 == UNK) {
		if (halfocc != 0) { // also allow UNK match when allowing half-occlusion, so crosschecking succeeds:
		    out.Pixel(x, y, 0) = dx0;
		}
		continue;
	    }
	    if (xonly || dy1 == UNK)
		dy1 = 0; // if only y component is unknown, assume 0

	    float dx = fabs(dx0 + dx1); // should have opposite signs
	    float dy = fabs(dy0 + dy1); // 0 if xonly==1
	    float dxi = fabs(dx0 + dx1i); // same with nearest neighbor values
	    float dyi = fabs(dy0 + dy1i);
	    dx = min(dx, dxi); // use smaller of the two, in case interpolated values includes outlier
	    dy = min(dy, dyi); // use smaller of the two, in case interpolated values includes outlier
	    float dd = dx*dx + dy*dy;

	    if (dd >= thresh * thresh && ((halfocc == 0)
					  || (halfocc < 0 &&  -dx0 > dx1)
					  || (halfocc > 0 &&  -dx0 < dx1)))
		continue; // crosschecking fails

	    // crosschecking succeeds:
	    out.Pixel(x, y, 0) = dx0;
	    if (! xonly)
		out.Pixel(x, y, 1) = dy0orig;  // perhaps was UNK
	}
    }

    return out;
}


// ( no longer used, see subpix2d below)
// estimation of subpixel offset based on 1D linear interpolation
// assume a, b, c increase linearly
// find position of value v w.r.t center value b (e.g. if v == b, return 0; if v = (a+b)/2 return -0.5)
float subpix(float v, float a, float b, float c) {
    float p=0, q=0, t=0;
    if (a < v && v <= b) {
	p = a; q = b; t = -1;
    } else if (b <= v && v < c) {
	p = b; q = c; t = 0;
    } else
	return 0; // model doesn't work, don't correct

    float d1 = v - p;
    float d2 = q - v;
    return d1 / (d1 + d2) + t;
}


// fit plane z = a*x + b*y + c to four fxy values; use f as reference value
// returns RMS residual error or INF if not successful
float fitplane4(float val, float f, float maxdiff, float f00, float f10, float f01, float f11, float &a, float &b, float &c)
{
    a = 0;
    b = 0;
    c = 0;
    // only use values within maxdiff of f
    int bad00 = (fabs(f00 - f) > maxdiff);
    int bad10 = (fabs(f10 - f) > maxdiff);
    int bad01 = (fabs(f01 - f) > maxdiff);
    int bad11 = (fabs(f11 - f) > maxdiff);

    if (bad00 + bad10 + bad01 + bad11 > 0)
	return INFINITY; // TODO: could allow one bad value, fit plane to other three

    // sanity check: val should be within 4 corner vals
    float mi = min(min(f00, f10), min(f01, f11));
    float ma = max(max(f00, f10), max(f01, f11));
    if (val < mi ||  val > ma)
	return INFINITY;

    // least-squares fit of A*x = m with A = [0 0 1;1 0 1; 0 1 1; 1 1 1]; x = [a b c]'; m = [f00 f10 f01 f11]'
    // using pseudo-inverse P = inv(A'*A)*A' gives x = P * m with
    // P = 0.25 * [-2 2 -2 2; -2 -2 2 2; 3 1 1 -1]
    a = 0.25 * (-2 * f00 + 2 * f10 - 2 * f01 + 2 * f11);
    b = 0.25 * (-2 * f00 - 2 * f10 + 2 * f01 + 2 * f11);
    c = 0.25 * ( 3 * f00 + 1 * f10 + 1 * f01 - 1 * f11);

    //residual
    float r00 = 0*a + 0*b + c - f00;
    float r10 = 1*a + 0*b + c - f10;
    float r01 = 0*a + 1*b + c - f01;
    float r11 = 1*a + 1*b + c - f11;

    return sqrt((r00*r00 + r10*r10 + r01*r01 + r11*r11) / 4.0);
}

// subpixel disparity estimation based on 3x3 code values indexed [x][y]
void subpix2d(float vx, float vy, float fx[3][3], float fy[3][3], float &corx, float &cory)
{
    corx = 0;
    cory = 0;

    float ffx = fx[1][1]; // center value
    float ffy = fy[1][1]; // center value
    float maxdiff = 2.0; // max allowable difference from ffx, ffy, i.e., max gradient of values to be fitted

    // determine correct quadrant
    int ix = (vx > ffx);
    int iy = (vy > ffy);

    // fit planes to the 4 corner values in quadrant
    float ax, bx, cx, ay, by, cy;
    float resx = fitplane4(vx, ffx, maxdiff, fx[ix][iy], fx[ix+1][iy], fx[ix][iy+1], fx[ix+1][iy+1], ax, bx, cx);
    float resy = fitplane4(vy, ffy, maxdiff, fy[ix][iy], fy[ix+1][iy], fy[ix][iy+1], fy[ix+1][iy+1], ay, by, cy);

    // if fit not good, don't correct
    float maxresid = 0.2;
    if (resx > maxresid || resy > maxresid) {
	corx = 0;
	cory = 0;
	return;
    }
    // now, want (px, py) s.t. ax*px + bx*py + cx = vx and ay*px + by*py + cy = vy
    // solve A*p = m with A= [ax bx; ay by]; p = [px; py]; m = [vx-cx; vy-cy]
    // p = 1/det(A) * [by -bx; -ay ax] * m
    float det = ax * by - bx * ay;
    if (det == 0) 
	return;
    float px = ( by * (vx - cx) - bx * (vy  - cy)) / det; 
    float py = (-ay * (vx - cx) + ax * (vy  - cy)) / det;

    // translate into right quadrant
    corx = px + ix - 1;
    cory = py + iy - 1;

    // make sure correction doesn't move too much
    float maxcor = .99;
    if (fabs(corx) > maxcor || fabs(cory) > maxcor) {
	corx = 0;
	cory = 0;
    }
}



void printstats(CIntImage rmin, CIntImage rmax)
{
    CShape sh = rmin.Shape();
    int ncodes = sh.width;

    int sumx = 0, sumy = 0;
    int maxx = 0, maxy = 0;
    int nx = 0, ny = 0;

    for(int vy = 0; vy < ncodes; vy++){
	for(int vx = 0; vx < ncodes; vx++){
	    int dx = rmax.Pixel(vx, vy, 0) - rmin.Pixel(vx, vy, 0);
	    int dy = rmax.Pixel(vx, vy, 1) - rmin.Pixel(vx, vy, 1);
	    if (dx >= 0) {
		sumx += dx;
		maxx = max(maxx, dx);
		nx++;
	    }
	    if (dy >= 0) {
		sumy += dy;
		maxy = max(maxy, dy);
		ny++;
	    }
	}
    }
    float f = 100.0 / (ncodes * ncodes);
    printf("avg range x = %.2f, max = %d (%.1f%% of code pairs)\n", (float)sumx / nx, maxx, f * nx);
    printf("avg range y = %.2f, max = %d (%.1f%% of code pairs)\n", (float)sumy / ny, maxy, f * ny);
}

// store location range of each rounded code value in rmin, rmax to speed up search
void initRange(CFloatImage code, int ncodes, CIntImage& rmin, CIntImage& rmax)
{
    CShape sh = code.Shape();
    int w = sh.width, h = sh.height;

    CShape sh2(ncodes, ncodes, 2);
    rmin.ReAllocate(sh2);
    rmax.ReAllocate(sh2);

    // initial range images (first pass)
    CIntImage rmin0(sh2);
    CIntImage rmax0(sh2);
    rmin0.FillPixels(w+h); // large value
    rmax0.FillPixels(-1);  // small value

    printf("precomputing ranges\n");

    // determine initial ranges rmin0, rmax0
    for(int y = 0; y < h; y++){
	for(int x = 0; x < w; x++){
	    float valx = code.Pixel(x, y, 0);
	    float valy = code.Pixel(x, y, 1);
	    if (valx == UNK || valy == UNK)
		continue;
	    int vx = max(0, min(ncodes-1, (int)round(valx)));
	    int vy = max(0, min(ncodes-1, (int)round(valy)));
	    rmin0.Pixel(vx, vy, 0) = min(x, rmin0.Pixel(vx, vy, 0));
	    rmin0.Pixel(vx, vy, 1) = min(y, rmin0.Pixel(vx, vy, 1));
	    rmax0.Pixel(vx, vy, 0) = max(x, rmax0.Pixel(vx, vy, 0));
	    rmax0.Pixel(vx, vy, 1) = max(y, rmax0.Pixel(vx, vy, 1));
	}
    }
    printstats(rmin0, rmax0);

    int neigh = 8; // 1, 4, or 8
    printf("blurring with %d neighbors\n", neigh);

    // "blur" ranges to include 1, 4, or 8 neighbors into rmin, rmax
    for(int y = 0; y < ncodes; y++){
	int ym = max(0, y-1);
	int yp = min(y+1, ncodes-1);
	for(int x = 0; x < ncodes; x++){
	    int xm = max(0, x-1);
	    int xp = min(x+1, ncodes-1);

	    int *rmi = &rmin.Pixel(x, y, 0);
	    int *mi1 = &rmin0.Pixel(xm, ym, 0), *mi2 = &rmin0.Pixel(x, ym, 0), *mi3 = &rmin0.Pixel(xp, ym, 0);
	    int *mi4 = &rmin0.Pixel(xm, y,  0), *mi5 = &rmin0.Pixel(x, y,  0), *mi6 = &rmin0.Pixel(xp, y,  0);
	    int *mi7 = &rmin0.Pixel(xm, yp, 0), *mi8 = &rmin0.Pixel(x, yp, 0), *mi9 = &rmin0.Pixel(xp, yp, 0);

	    int *rma = &rmax.Pixel(x, y, 0);
	    int *ma1 = &rmax0.Pixel(xm, ym, 0), *ma2 = &rmax0.Pixel(x, ym, 0), *ma3 = &rmax0.Pixel(xp, ym, 0);
	    int *ma4 = &rmax0.Pixel(xm, y,  0), *ma5 = &rmax0.Pixel(x, y,  0), *ma6 = &rmax0.Pixel(xp, y,  0);
	    int *ma7 = &rmax0.Pixel(xm, yp, 0), *ma8 = &rmax0.Pixel(x, yp, 0), *ma9 = &rmax0.Pixel(xp, yp, 0);

	    for (int b = 0; b < 2; b++) {
		rmi[b] = mi5[b];
		rma[b] = ma5[b];
		if (neigh >= 4) { // blur with 4-neighbors
		    rmi[b] = min(rmi[b], min(min(mi2[b], mi4[b]), min(mi6[b], mi8[b])));
		    rma[b] = max(rma[b], max(max(ma2[b], ma4[b]), max(ma6[b], ma8[b])));
		}
		if (neigh == 8) { // blur with diagonal vals as well to get 8-neighbors
		    rmi[b] = min(rmi[b], min(min(mi1[b], mi3[b]), min(mi7[b], mi9[b])));
		    rma[b] = max(rma[b], max(max(ma1[b], ma3[b]), max(ma7[b], ma9[b])));
		}
	    }
	}
    }
    printstats(rmin, rmax);
}


// new fast code for matching images DS 2/6/2014
// preprocesses code map to find search range for each code value
// find matches between code images fim0 and fim1, store in flow image dim
// if search range is now known, pass in dmin = dmax = 0
void matchImages(CFloatImage fim0, CFloatImage fim1, CFloatImage dim, int dmin, int dmax, int ymin, int ymax)
{
    CShape sh = fim0.Shape();
    int w = sh.width, h = sh.height;

    // maximal allowable code difference:
    float maxdiff = 0.5;
    float maxdiffsq = maxdiff * maxdiff;

    int ncodes = 1024;
    CIntImage rmin, rmax;
    initRange(fim1, ncodes, rmin, rmax);

    int userange = (dmin < dmax);
    if (userange) // further restrict to given search range
	printf("restricting to given ranges %d..%d, %d..%d\n", dmin, dmax, ymin, ymax);
    else
	printf("ignoring given ranges\n");

    int good = 0;
    int unique = 0;

    for(int y0 = 0; y0 < h; y0++){
	if (y0 % 100 == 0) printf(".");
	fflush(stdout);

	for(int x0 = 0; x0 < w; x0++){
	    dim.Pixel(x0, y0, 0) = UNK;
	    dim.Pixel(x0, y0, 1) = UNK;

	    float valx = fim0.Pixel(x0, y0, 0);
	    float valy = fim0.Pixel(x0, y0, 1);

	    if (valx == UNK || valy == UNK)
		continue;

	    int vx = max(0, min(ncodes-1, (int)round(valx)));
	    int vy = max(0, min(ncodes-1, (int)round(valy)));

	    int rxmin = rmin.Pixel(vx, vy, 0);
	    int rymin = rmin.Pixel(vx, vy, 1);
	    int rxmax = rmax.Pixel(vx, vy, 0);
	    int rymax = rmax.Pixel(vx, vy, 1);
	    if (userange) { // further restrict to given search range
		rxmin = max(rxmin, x0 + dmin);
		rxmax = min(rxmax, x0 + dmax);
		rymin = max(rymin, y0 + ymin);
		rymax = min(rymax, y0 + ymax);
	    }

	    int bestx = 0;
	    int besty = 0;
	    int bestcnt = 0;
	    float bestdiffsq = 2 * maxdiffsq; // no need updating min unless close to allowable value


	    for(int y1 = rymin; y1 <= rymax; y1++){
		if (y1 < 0 || y1 >= h) {
		    printf("y = %d shouldn't happen\n", y1);
		    continue;
		}

		for(int x1 = rxmin; x1 <= rxmax; x1++){
		    if (x1 < 0 || x1 >= w) {
			printf("x shouldn't happen\n");
			continue;
		    }

		    float valx1 = fim1.Pixel(x1, y1, 0);
		    float valy1 = fim1.Pixel(x1, y1, 1);
		    
		    float difx = valx - valx1;
		    float dify = valy - valy1;
		    float diffsq = difx * difx + dify * dify;

		    if (diffsq <= bestdiffsq) {
			int dx = x1 - x0;
			int dy = y1 - y0;
			if (diffsq < bestdiffsq) {
			    bestdiffsq = diffsq;
			    bestx = dx;
			    besty = dy;
			    bestcnt = 1;
			} else { // found another equally good value
			    bestx += dx;
			    besty += dy;
			    bestcnt++;
			}
		    }
		}
	    }


	    if (bestdiffsq <= maxdiffsq){ // found a good match
		good++;
		if (bestcnt == 1) { // unique best value, attempt subpixel estimation:
		    unique++;
		    int x1 = (int)round(x0 + bestx);
		    int y1 = (int)round(y0 + besty);
		    int x1m = max(0, x1-1), x1p = min(w-1, x1+1);
		    int y1m = max(0, y1-1), y1p = min(h-1, y1+1);
		    // old: 2 separate 1D corrections
		    //float corx = subpix(valx, fim1.Pixel(x1m, y1, 0), fim1.Pixel(x1, y1, 0), fim1.Pixel(x1p, y1, 0));
		    //float cory = subpix(valy, fim1.Pixel(x1, y1m, 1), fim1.Pixel(x1, y1, 1), fim1.Pixel(x1, y1p, 1));
		    // new: combined 2D correction
		    float corx, cory;
		    // 3x3 float arrays, indexed [x][y]!!!
		    float fx[3][3] = {{fim1.Pixel(x1m, y1m, 0), fim1.Pixel(x1m, y1, 0), fim1.Pixel(x1m, y1p, 0)},
				      {fim1.Pixel(x1,  y1m, 0), fim1.Pixel(x1,  y1, 0), fim1.Pixel(x1,  y1p, 0)},
				      {fim1.Pixel(x1p, y1m, 0), fim1.Pixel(x1p, y1, 0), fim1.Pixel(x1p, y1p, 0)}};
		    float fy[3][3] = {{fim1.Pixel(x1m, y1m, 1), fim1.Pixel(x1m, y1, 1), fim1.Pixel(x1m, y1p, 1)},
				      {fim1.Pixel(x1,  y1m, 1), fim1.Pixel(x1,  y1, 1), fim1.Pixel(x1,  y1p, 1)},
				      {fim1.Pixel(x1p, y1m, 1), fim1.Pixel(x1p, y1, 1), fim1.Pixel(x1p, y1p, 1)}};
		    subpix2d(valx, valy, fx, fy, corx, cory);
		    //corx = 0;
		    //cory = 0;
		    dim.Pixel(x0, y0, 0) = bestx + corx;
		    dim.Pixel(x0, y0, 1) = besty + cory;

		    if (isnan(dim.Pixel(x0, y0, 0)))
			printf("error: dx(%d, %d) = %f\n", x0, y0, dim.Pixel(x0, y0, 0));
		    if (isnan(dim.Pixel(x0, y0, 1))) {
			printf("error: dy(%d, %d) = %f\n", x0, y0, dim.Pixel(x0, y0, 1));
			printf("valy=%f besty=%d cory=%f\n", valy, besty, cory);
			printf("%f %f %f\n", fim1.Pixel(x1, y1m, 1), fim1.Pixel(x1, y1, 1), fim1.Pixel(x1, y1p, 1));
		    }
		} else { // more than one equally good code, don't interpolate, just use average
		    float scale = 1.0 / bestcnt;
		    dim.Pixel(x0, y0, 0) = scale * bestx;
		    dim.Pixel(x0, y0, 1) = scale * besty;
		}
	    }
	}
    }

    printf("found %d matches, %d unique (maxdiff=%.2f)\n", good, unique, maxdiff);
}



// compute pair of disparity maps from code images
void computeDisparities(char *in0, char *in1, char *out0, char *out1, int dXmin, int dXmax, int dYmin, int dYmax)
{
    int verbose=1;

    CFloatImage fim0, fim1;

    ReadFlowFileVerb(fim0, in0, verbose);
    ReadFlowFileVerb(fim1, in1, verbose);

    if (fim0.Shape() != fim1.Shape())
	throw CError("computeDisparities: all images need to have same size");

    CFloatImage d0(fim0.Shape());
    CFloatImage d1(fim0.Shape());

    matchImages(fim0, fim1, d0, -dXmax, -dXmin, -dYmax, -dYmin);
    WriteFlowFileVerb(d0, out0, verbose);

    matchImages(fim1, fim0, d1, dXmin, dXmax, dYmin, dYmax);
    WriteFlowFileVerb(d1, out1, verbose);
}


// cross check pair of float disp maps
// thresh = allowable Euclidean distance
// if xonly==1, ignore y channel
// if halfocc==1, allow half occlusion
void runCrossCheck(char *in0, char *in1, char *out0, char *out1, float thresh, int xonly, int halfocc)
{
    int verbose=1;

    CFloatImage d0, d1;

    ReadFlowFileVerb(d0, in0, verbose);
    ReadFlowFileVerb(d1, in1, verbose);

    if (d0.Shape() != d1.Shape())
	throw CError("runCrossCheck: all images need to have same size");

    if (verbose)
	printf("cross-checking with thresh=%g, xonly=%d, halfocc=%d\n", thresh, xonly, halfocc);

    CFloatImage crossed0 = floatCrossCheck(d0, d1, thresh, xonly, -halfocc);
    CFloatImage crossed1 = floatCrossCheck(d1, d0, thresh, xonly,  halfocc);

    WriteFlowFileVerb(crossed0, out0, verbose);
    WriteFlowFileVerb(crossed1, out1, verbose);
}




//////////////////////////////////////////////////////////////////////////////////////////////////////
// Filtering



// mark x disparities invalid if |y disparity| > ythresh
void removeLargeYdisps(CFloatImage img, float ythresh) {
    CShape sh = img.Shape();
    int w = sh.width, h = sh.height;

    for (int y = 0; y < h; y++) {
	for (int x = 0; x < w; x++) {
	    float fy = img.Pixel(x, y, 1);
	    if (fy != UNK && fabs(fy) > ythresh)
		img.Pixel(x, y, 0) = UNK; // xdisp
	}
    }
}


void fillDispHoles(CFloatImage img, int band, vector<struct ccomp> comp, CIntImage compimg, CFloatImage& residimg, int maxpixels) {
    int maxsize = (int)(2.0 * sqrt(maxpixels)); // max dimension of hole (i.e. max aspect ratio = 1:4)

    CShape sh = img.Shape();
    int width = sh.width, height = sh.height;

    sh.nBands = 1;
    residimg.ReAllocate(sh);
    residimg.FillPixels(UNK);

    int n = 0;
    for (int k=1; k < (int)comp.size(); k++) {
	struct ccomp cc = comp[k];
	int debug = 0;
	//if (abs(cc.x1 - 610) < 50 && abs(cc.y1 - 1580) < 50)
	//    debug = 1;
	int dx = cc.x2 - cc.x1;
	int dy = cc.y2 - cc.y1;
	if (dx <= maxsize && dy <= maxsize && cc.n <= maxpixels) {
	    if (debug)
		printf("k=%3d, n=%3d, x=%4d..%4d, y=%4d..%4d  ", k, cc.n, cc.x1, cc.x2, cc.y1, cc.y2);
	    int borderx = max(3, 6-dx); // pixels to include around each hole
	    int bordery = max(3, 6-dy); // pixels to include around each hole
	    int x1 = max(cc.x1 - borderx, 0);
	    int x2 = min(cc.x2 + borderx, width-1);
	    int y1 = max(cc.y1 - bordery, 0);
	    int y2 = min(cc.y2 + bordery, height-1);
	    vector<float> vx, vy, vz;
	    for (int y=y1; y<=y2; y++) {
		for (int x=x1; x<=x2; x++) {
		    float z = img.Pixel(x, y, band);
		    if (z != UNK) {
			vx.push_back(x-x1);
			vy.push_back(y-y1);
			vz.push_back(z);
		    }
		}
	    }
	    float pa=0, pb=0, pc=0;
	    fitPlane(vx, vy, vz, pa, pb, pc);
	    if (debug)
		printf("a=%5.2f b=%5.2f c=%6.1f  ", pa, pb, pc);
		
	    // compute residual
	    vector<float> res;
	    for (int y=y1; y<=y2; y++) {
		for (int x=x1; x<=x2; x++) {
		    float r = UNK;
		    float z = img.Pixel(x, y, band);
		    if (z != UNK) {
			float z2 = pa * (x-x1) + pb * (y-y1) + pc;
			r = z - z2;
			res.push_back(fabs(r));
		    }
		    residimg.Pixel(x, y, 0) = r;
		}
	    }
	    std::sort(res.begin(), res.end());
	    int np = res.size();
	    float q75 = res[75 * np / 100];
	    float q75thresh = 0.5; // require 75% of border pixels within this
	    float q90 = res[90 * np / 100];
	    float q90thresh = 1.0; // require 90% of border pixels within this
	    int minpts = 10; // require at least this many border pixels
	    int fillhole = (np >= minpts && q75 <= q75thresh && q90 <= q90thresh);
	    if (debug)
		printf("np=%3d, q75=%5.2f, q90=%5.2f, filling: %s\n", np, q75, q90, fillhole ? "YES" : "NO");
	    if (fillhole) {
		n++;
		for (int y=y1; y<=y2; y++) {
		    for (int x=x1; x<=x2; x++) {
			float z = img.Pixel(x, y, band);
			float z2 = pa * (x-x1) + pb * (y-y1) + pc;
			if (z == UNK) {
			    if (compimg.Pixel(x, y, 0) == k) // this hole, not another one
				img.Pixel(x, y, band) = z2; // fill hole
			} else { // if not hole but residual is high, use plane value instead...  dangerous?
			    if (fabs(z - z2) > q90thresh) {
				img.Pixel(x, y, band) = z2; // overwrite outlier
			    }
			}
		    }
		}
		// mark corner of residual image to indicate success
		residimg.Pixel(x1, y1, 0) = 3.0; // green in rainbow color map
	    }
	}
    }
    printf("%d / %d holes filled\n", n, (int)comp.size()-1);
}

void removeSmallComponents(CFloatImage img, int band, vector<struct ccomp> comp, CIntImage compimg, int mincompsize)
{
    CShape sh = img.Shape();
    int width = sh.width, height = sh.height;

    for (int y = 0; y < height; y++) {
	for (int x = 0; x < width; x++) {
	    int k = compimg.Pixel(x, y, 0);
	    if (k > 0 && comp[k].n < mincompsize)
		img.Pixel(x, y, band) = UNK;
	}
    }
    int n = 0;
    for (int k=1; k < (int)comp.size(); k++) {
	if (comp[k].n < mincompsize)
	    n++;
    }
    printf("%d / %d components removed\n", n, (int)comp.size()-1);
}


// filter a disparity map - do some or all of the following:
// 1. invalidate all pixels with |ydisp| > ythresh  (if ythresh >= 0)
// 2. run median filters in x and y channels        (if kx > 1 and/or ky > 1)
// 3. remove small x-disparity components with size < mincompsize
// 3. fill x-disp holes with size <= maxholesize where surrounding disps fit plane model
void runFilter(char *srcfile, char *dstfile, float ythresh, int kx, int ky, int mincompsize, int maxholesize)
{
    int verbose=1;

    int debugimgs = 0;

    CFloatImage img, img2;
    
    ReadFlowFileVerb(img, srcfile, verbose);
    if (debugimgs)
	WriteBand(img, 0, -1, "im0_orig.pfm", verbose);

    if (ythresh >= 0) {
	if (verbose) fprintf(stderr, "invalidating pixels with |ydisp| > %g\n", ythresh);
	removeLargeYdisps(img, ythresh);
	if (debugimgs)
	    WriteBand(img, 0, -1, "im1_ythresh.pfm", verbose);
    }
    if (kx > 1) {
	if (verbose) fprintf(stderr, "running %dx%d median filter in x\n", kx, kx);
	medianfilter(img, img2, kx, 0);
	img = img2;
	if (debugimgs)
	    WriteBand(img, 0, -1, "im2_medianfiltered.pfm", verbose);
    }

    if (ky > 1) {
	if (verbose) fprintf(stderr, "running %dx%d median filter in y\n", ky, ky);
	medianfilter(img, img2, ky, 1);
	img = img2;
    }

    if (mincompsize > 0) {
	float thresh = 2.0; // allowable difference to be considered same component (i.e. disparity gradient)
	if (verbose) fprintf(stderr, "removing dispcomps smaller than %d (thresh=%g)\n", mincompsize, thresh);
	CIntImage compimg;
	vector<struct ccomp> comp = computeDispComponents(img, 0, compimg, thresh);
	removeSmallComponents(img, 0, comp, compimg, mincompsize);
	if (debugimgs)
	    WriteBand(img, 0, -1, "im3_compsremoved.pfm", verbose);
    }

    if (maxholesize > 0) {
	if (verbose) 
	    fprintf(stderr, "filling holes up to %d pixels\n", maxholesize);
	CIntImage compimg;
	vector<struct ccomp> comp = computeUnkComponents(img, 0, compimg);

	CFloatImage residimg;
	fillDispHoles(img, 0, comp, compimg, residimg, maxholesize);
	if (debugimgs) {
	    WriteBand(img, 0, -1, "im4_holesfilled.pfm", verbose);
	    WriteImageVerb(residimg, "im5_resid.pfm", verbose);
	}
    }

    WriteFlowFileVerb(img, dstfile, verbose);
}





//////////////////////////////////////////////////////////////////////////////////////////////////////
// Merging


void mergeDisparityMaps(char* output, char** filenames, int count, int mingroup, float maxdiff)
{
    int verbose = 1;
    CFloatImage images[count];

    for(int i =0; i < count; i++){
	ReadFlowFileVerb(images[i], filenames[i], verbose);
    }

    CFloatImage out;
    CShape sh = images[0].Shape();
    out.ReAllocate(sh);

    for(int j =0; j < sh.height; j++){
	if(j % 100 == 0){
	    printf(".");
	    fflush(stdout);
	}

	float* row[count];
	for(int k =0; k < count; k++){
	    row[k] = &images[k].Pixel(0,j,0);
	}

	float* outrow = &out.Pixel(0,j,0);

	for(int i =0; i < sh.width; i++){

	    float newvalx = 0, newvaly = 0;
	    int countx = 0, county = 0;
	    int x = i*2;
	    int y = x+1;
	    for(int k =0; k < count; k++){

		if (row[k][x] != UNK) {
		    newvalx += row[k][x];
		    countx++;
		}

		if (row[k][y] != UNK ) {
		    newvaly += row[k][y];
		    county++;
		}

	    }
	    if(countx < mingroup){
		outrow[x] = UNK;
	    }else{
		newvalx /= countx;
		outrow[x] = newvalx;
	    }

	    if(county < mingroup){
		outrow[y] = UNK;
	    }else{
		newvaly /= county;
		outrow[y] = newvaly;
	    }

	    // at this point, outrow[x/y] (and newvalx/y) contains average of all valid pixels


	    // this is the old merging code, trying to make sense of it
	    for(int k =0; k < count; k++){ // for all imges
		if(row[k][x] != UNK  && fabs(row[k][x] - newvalx) > maxdiff){ // if find pixel far from average
		    vector<float> pixels;
		    for(int z =0; z < count; z++){ // for all imgages again??
			if(row[z][x] != UNK){
			    pixels.push_back(row[z][x]); // collect all pixels
			}
		    }
		    if((int)pixels.size() < mingroup){ // seems like this shouldn't happen, filtered earlier...
			outrow[x] = UNK;

		    }else{
			outrow[x] = robustAverage(pixels, maxdiff, mingroup); // call robust avg (in Utils.cpp)
                if ((0)){
			    printf("values were: ");
			    for(int i = 0; i < (int)pixels.size(); i++){
				printf(" %.2f",pixels[i]);
			    }
			    printf("\n");
			    printf("average was: %f\n\n",outrow[x]);
			}
		    }
		    break; // and break k loop
		}
	    }
	}

    }
    printf("\n");
    WriteFlowFileVerb(out, output, 1);
}


// final merge, ignores y channel of .flo images
// input:
//  maxdiff -- threshold for robust average
//  mdisp   -- high-confidence merged view disparities from previous stage
//  vdisps  -- nV individual view disparities
//  rdisps  -- nR individual illumination disps
// outputs:
//  outd  -- merged disparities
//  outsd -- std dev of merged disparities (i.e. RMS error)
//  outn  -- number of samples N
void mergeDisparityMaps2(float maxdiff, int nV, int nR, char* outdfile, char* outsdfile, char* outnfile, char *inmdfile, char **invdfiles, char **inrdfiles)
{
    int verbose = 1;
    CFloatImage mdisp;
    CFloatImage vdisps[nV];
    CFloatImage rdisps[nR];

    ReadFlowFileVerb(mdisp, inmdfile, verbose);
    CShape sh = mdisp.Shape();
    for (int i = 0; i < nV; i++)
	ReadFlowFileVerb(vdisps[i], invdfiles[i], verbose);
    for (int i = 0; i < nR; i++)
	ReadFlowFileVerb(rdisps[i], inrdfiles[i], verbose);

    CFloatImage outd(sh); // merged disparities
    sh.nBands = 1;
    CFloatImage outsd(sh); // stddev of disps
    CByteImage outn(sh);  // samples N used per pixel

    float vals[nV + nR];

    for (int y = 0; y < sh.height; y++) {
	if (y % 100 == 0) {
	    printf(".");
	    fflush(stdout);
	}

	for (int x = 0; x < sh.width; x++) {
	    int i;

	    int k = 0;

	    for (i = 0; i < nV; i++) {
		float vd = vdisps[i].Pixel(x, y, 0);
		if (vd != UNK)
		    vals[k++] = vd;
	    }
	    int kv = k;

	    for (i = 0; i < nR; i++) {
		float rd = rdisps[i].Pixel(x, y, 0);
		if (rd != UNK)
		    vals[k++] = rd;
	    }

	    // initialize output images to default (UNK) values
	    outn.Pixel(x, y, 0) = 0;
	    outd.Pixel(x, y, 0) = UNK;
	    outd.Pixel(x, y, 1) = UNK;
	    outsd.Pixel(x, y, 0) = UNK;

	    float md = mdisp.Pixel(x, y, 0); // see if have reference value from merge1 step
	    
	    if (md == UNK && kv > 0) // if not, try using median of viewdisps
		md = median2(vals, kv);

	    if (md == UNK && k > 0) // if still no value, use median of all values
		md = median2(vals, k);

	    if (md == UNK)
		continue;

	    // now, collect statistics of vals that are within maxdist of reference value
	    // for numerical stability, compute SD of residuals w.r.t. md
	    float s = 0;
	    double sr = 0;
	    double srr = 0;
	    int n = 0;
	    for (i = 0; i < k; i++) {
		float d = vals[i];
		double r = d - md;
		if (fabs(r) > maxdiff)
		    continue;
		s += d;
		sr += r;
		srr += r * r;
		n++;
	    }
	    if (n < 1)
		continue;
	    outn.Pixel(x, y, 0) = n;
	    outd.Pixel(x, y, 0) = s / n;
	    outsd.Pixel(x, y, 0) = (n > 1 ? sqrt((srr - sr*sr/n) / (n - 1.0)) : UNK);
	}
    }
    printf("\n");
    WriteFlowFileVerb(outd, outdfile, verbose);
    WriteImageVerb(outsd, outsdfile, verbose);
    WriteImageVerb(outn, outnfile, verbose);
}


// clipping to given disparity range and update of stddev and N files after filtering
// inputs/outputs:
//   imd  -- final merged and filtered  disparities
//   imsd -- std dev of merged disparities (i.e. RMS error)
//   imn  -- number of samples N
// inputs:
//   dmin, dmax -- range of valid disparities
// update d:
//   set to UNK if d < dmin or d > dmax
// update sd and n:
//   if d == UNK, set n to 0 and sd to UNK
//   if d != UNK but n == 0, set n to 1 and sd to UNK (which it should be already)
void clipdisps(char* indfile, char* insdfile, char* innfile, char* outdfile, char* outsdfile, char* outnfile, float dmin, float dmax)
{
    int verbose = 1;
    CFloatImage imd, imsd;
    CByteImage imn;
    ReadFlowFileVerb(imd, indfile, verbose);
    ReadImageVerb(imsd, insdfile, verbose);
    ReadImageVerb(imn, innfile, verbose);

    CShape sh = imd.Shape();

    int c = 0;
    int n = 0;
    for (int y = 0; y < sh.height; y++) {
	for (int x = 0; x < sh.width; x++) {
	    float d = imd.Pixel(x, y, 0);
	    if (d != UNK) {
		n++;
		if (d < dmin || d > dmax) {
		    d = UNK;
		    c++;
		}
	    }
	    if (d == UNK) {
		imd.Pixel(x, y, 0) = UNK;
		imd.Pixel(x, y, 1) = UNK;
		imn.Pixel(x, y, 0) = 0;
		imsd.Pixel(x, y, 0) = UNK;
	    } else {
		if (imn.Pixel(x, y, 0) == 0) {
		    imn.Pixel(x, y, 0) = 1;
		    imsd.Pixel(x, y, 0) = UNK;
		}
	    }
	}
    }
    if (verbose)
	fprintf(stderr, "%d pixels (%6.3f%% of valid disparities) clipped\n", c, 100.0 * c / n);

    WriteFlowFileVerb(imd, outdfile, verbose);
    WriteImageVerb(imsd, outsdfile, verbose);
    WriteImageVerb(imn, outnfile, verbose);
}


// masking out of manually identified incorrect pixels
// input/output:
//   disp -- .flo disparities
// inputs:
//   mask -- .pgm file, where mask==0 set imd to UNK
void maskdisps(char *indfile, char *outdfile, char *mfile)
{
    int verbose = 1;
    CFloatImage disp;
    CByteImage mask;
    ReadFlowFileVerb(disp, indfile, verbose);
    ReadImageVerb(mask, mfile, verbose);

    CShape sh = disp.Shape();

    int c = 0;
    int n = 0;
    for (int y = 0; y < sh.height; y++) {
	for (int x = 0; x < sh.width; x++) {
	    float d = disp.Pixel(x, y, 0);
	    int m = mask.Pixel(x, y, 0);
	    if (d != UNK) {
		n++;
		if (m == 0) {
		    c++;
		    disp.Pixel(x, y, 0) = UNK;
		    disp.Pixel(x, y, 1) = UNK;
		}
	    }
	}
    }
    if (verbose)
	fprintf(stderr, "%d pixels (%6.3f%% of valid disparities) masked\n", c, 100.0 * c / n);

    WriteFlowFileVerb(disp, outdfile, verbose);
}



/* ***********************************************************************************

// old code

// code for matching images DS 1/17/2014
// find matches between code images fim0 and fim1, store in flow image dim
// slow version, don't use
void matchImages_slow(CFloatImage fim0, CFloatImage fim1, CFloatImage dim, int dmin, int dmax, int ymin, int ymax)
{
    CShape sh = fim0.Shape();
    int w = sh.width, h = sh.height;

    // maximal allowable code difference:
    float maxdiff = 0.5;
    float maxdiffsq = maxdiff * maxdiff;

    int good = 0;
    int unique = 0;

    for(int y0 = 0; y0 < h; y0++){
	if (y0 % 100 == 0) printf(".");
	fflush(stdout);

	for(int x0 = 0; x0 < w; x0++){
	    dim.Pixel(x0, y0, 0) = UNK;
	    dim.Pixel(x0, y0, 1) = UNK;

	    float valx = fim0.Pixel(x0, y0, 0);
	    float valy = fim0.Pixel(x0, y0, 1);

	    if (valx == UNK || valy == UNK)
		continue;

	    int bestx = 0;
	    int besty = 0;
	    int bestcnt = 0;
	    float bestdiffsq = 2 * maxdiffsq; // no need updating min unless close to allowable value

	    for(int dy = ymin; dy <= ymax; dy++){
		int y1 = y0 + dy;
		if (y1 < 0 || y1 >= h)
		    continue;

		float* row1 = &fim1.Pixel(0, y1, 0);

		for(int dx = dmin; dx <= dmax; dx++){
		    int x1 = x0 + dx;
		    if (x1 < 0 || x1 >= w)
			continue;

		    float valx1 = row1[x1 + x1];
		    float valy1 = row1[x1 + x1 + 1];
		    
		    float difx = valx - valx1;
		    float dify = valy - valy1;
		    float diffsq = difx * difx + dify * dify;

		    if (diffsq <= bestdiffsq) {
			if (diffsq < bestdiffsq) {
			    bestdiffsq = diffsq;
			    bestx = dx;
			    besty = dy;
			    bestcnt = 1;
			} else { // found another equally good value
			    bestx += dx;
			    besty += dy;
			    bestcnt++;
			}
		    }
		}
	    }


	    if (bestdiffsq <= maxdiffsq){ // found a good match
		good++;
		if (bestcnt == 1) { // unique best value, attempt subpixel estimation:
		    unique++;
		    int x1 = x0 + bestx;
		    int y1 = y0 + besty;
		    int x1m = max(0, x1-1), x1p = min(w-1, x1+1);
		    int y1m = max(0, y1-1), y1p = min(h-1, y1+1);
		    float corx = subpix(valx, fim1.Pixel(x1m, y1, 0), fim1.Pixel(x1, y1, 0), fim1.Pixel(x1p, y1, 0));
		    float cory = subpix(valy, fim1.Pixel(x1, y1m, 1), fim1.Pixel(x1, y1, 1), fim1.Pixel(x1, y1p, 1));
		    dim.Pixel(x0, y0, 0) = bestx + corx;
		    dim.Pixel(x0, y0, 1) = besty + cory;
		} else { // more than one equally good code, don't interpolate, just use average
		    float scale = 1.0 / bestcnt;
		    dim.Pixel(x0, y0, 0) = scale * bestx;
		    dim.Pixel(x0, y0, 1) = scale * besty;
		}
	    }
	}
    }

    printf("found %d matches, %d unique (maxdiff=%.2f)\n", good, unique, maxdiff);
}


*/
