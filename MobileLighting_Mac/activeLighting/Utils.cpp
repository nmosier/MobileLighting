///////////////////////////////////////////////////////////////////////////
//
// NAME
//  Utils.cpp -- utility functions associated with active lighting project
//
//
// Copyright � Daniel Scharstein, 2002.
//
///////////////////////////////////////////////////////////////////////////

#include <stdio.h>
#include <stdlib.h>
#include "imageLib.h"
#include <utility>
#include <stdarg.h>
#include <vector>
#include <algorithm>
#include <math.h>
#include "opencv2/opencv.hpp"
#include "Utils.h"
#include "flowIO.h"



///////////////////////////////////////////////////////////////////////////
// color encoding

// map f from 0.0 .. 1.0 to hue (Red-Yellow-Green-Cyan-Blue-Magenta)
void hue(float f, uchar *rgb) {
    float r=0.0, g=0.0, b=0.0;
    f *=6.0;
    int f0 = (int)f;
    f -= f0;
    switch (f0) {
    case 0:  r=1.0;   g=f; break;
    case 1:  r=1.0-f; g=1.0; break;
    case 2:  g=1.0;   b=f; break;
    case 3:  g=1.0-f; b=1.0; break;
    case 4:  b=1.0;   r=f; break;
    default: b=1.0-f; r=1.0; break;
    }
    rgb[2] = r*255;
    rgb[1] = g*255;
    rgb[0] = b*255;
}

// given value f = -1..1, adjusts rgb values to black for f=-1 and white for f=1
void adjust_brightness(float f, uchar *rgb) {
    if (f < 0) {
	for (int i=0; i<3; i++)
	    rgb[i] *= (f+1);
    } else {
	for (int i=0; i<3; i++)
	    rgb[i] = (1-f)*rgb[i] + f*255;
    }
}

// map f from 0.0 .. 1.0 to spiral in Hue-Brightness space 
// rounds controls how many spirals in 0.0..1.0 (e.g. rounds=100 -> one spiral = 0.01)
void hueshade(float f, uchar *rgb, float rounds) {
    f = __max(0, __min(1, f));
    float f1 = f*rounds;
    f1 = f1 - (int)f1;
    hue(f1, rgb);
    // map f to subset of [-1, 1] (don't want full range o/w don't see colors at extrema)
    f = 1.6*f - 0.8;
    adjust_brightness(f, rgb);
}


///////////////////////////////////////////////////////////////////////////
// filtering


// there seems to be a faster way via std::nth_element, but this is good enough for now :)
// if vector is empty, return UNK
float median(vector<float> v)
{
    if (v.size() == 0)
	return UNK;
    std::sort(v.begin(), v.end());
    return v[v.size()/2];
}

// this seems way faster...
float median(float* v, int n)
{
    if (n == 0)
	return UNK;
    std::sort(v, v+n);
    return v[n/2];
}

// version that forms average of center two numbers if n is even
float median2(float* v, int n)
{
    if (n == 0)
	return UNK;
    std::sort(v, v+n);
    if (n % 2 == 1)
	return v[n/2]; // n is odd
    else
	return (v[n/2 - 1] + v[n/2]) / 2.0;
}

// special case for 3x3 filter with "symmetric hole filling" and careful averaging
float median3x3(float* v, int n)
{
    float maxdiff = 2.0;
    if (n == 9) { // n can be smaller on image border
	float c = v[4]; // center val
	if (c != UNK) {
	    // symmetric hold filling with opposite value x reflected on center value c:
	    // h = c - (x - c)
	    // only do if value |x-c| <= maxdiff
	    for (int k = 0; k < 9; k++) {
		int j = 8-k; // index of opposite value in 3x3 window
		if (j == k)
		    continue;
		if (v[k] == UNK && v[j] != UNK) {
		    float d = v[j] - c;
		    if (fabs(d) <= maxdiff)
			v[k] = c - d;
		}
	    }
	}
	std::sort(v, v+n);
	int k = n;
	while (k > 0 && v[k-1] == UNK)
	    k--;
	// now v[0] .. v[k-1] are not UNK
	if (k < 4) // if less than 4 good vals (6 or more UNK), make UNK  (could use 5 here, but fills more holes)
	    return UNK;
	if (k % 2 == 0) {
	    float v1 = v[k/2 - 1];
	    float v2 = v[k/2];
	    if (fabs(v1 - v2) <= maxdiff)
		return (v1 + v2) / 2.0;
	    else 
		return v1;
	} else {
	    float v1 = v[k/2 - 1];
	    float v2 = v[k/2];
	    float v3 = v[k/2 + 1];
	    float d12 = fabs(v1 - v2);
	    float d23 = fabs(v2 - v3);
	    if (d12 <= maxdiff && d23 <= maxdiff)
		return (v1 + v2 + v3) / 3.0;
	    else if (d12 <= maxdiff)
		return (v1 + v2) / 2.0;
	    else if (d23 <= maxdiff)
		return (v2 + v3) / 2.0;
	    else 
		return v2;
	}
    } 
    // end special case n == 9
    // otherwise do the standard median computation
    std::sort(v, v+n);
    return v[n/2];
}


/* not used
// median over 3x3 window centered at x, y
// assumes no bound check necessary
float median3x3filter(CFloatImage &im, int x, int y, int nb)
{
    float *a1 = &im.Pixel(x, y-1, 0);
    float *a2 = &im.Pixel(x, y,   0);
    float *a3 = &im.Pixel(x, y+1, 0);
    float a[] = {a1[-nb], a1[0], a1[nb],
		 a2[-nb], a2[0], a2[nb],
		 a3[-nb], a3[0], a3[nb]};
    std::sort(a, a+9);
    return a[4];
}
*/


// k x k median filter of band b in float image, assume k is odd
void medianfilter(CFloatImage src, CFloatImage &dst, int k, int b)
{
    CShape sh = src.Shape();
    dst.ReAllocate(sh);
    int width = sh.width, height = sh.height;
    int x, y, xx, yy;
    int rad = k / 2;

    vector<float> v;
    v.resize(k*k);

    for (y = 0; y < height; y++) {
	int y1 = max(0, y-rad);
	int y2 = min(height-1, y+rad);
	for (x = 0; x < width; x ++) {
	    if (k <= 1) {
		dst.Pixel(x, y, b) = src.Pixel(x, y, b);
		continue;
	    }
	    int x1 = max(0, x-rad);
	    int x2 = min(width-1, x+rad);
	    int j = 0;
	    for (yy = y1; yy <= y2; yy++) {
		for (xx = x1; xx <= x2; xx++) {
		    float f = src.Pixel(xx, yy, b);
		    v[j++] = f; // include UNK!
		    //v.push_back(f); // slower
		}
	    }
	    float m = 0;
	    if (k==3)
		m = median3x3(&v[0], j); // special case with "symmetric hole filling"
	    else
		m = median(&v[0], j);
	    //float m = median(v); // slower
	    dst.Pixel(x, y, b) = m;
	    if (0 && x == 182 && y == 975) {
		for (int i=0; i < (int)v.size(); i++)
		    printf("%5.1f ", v[i]);
		printf("\nk=%d, rad = %d, v.size = %d, med = %g\n", k, rad, (int)v.size(), m);
	    }
	}
    }
}


//////////////////////////////////////////////////////////////////////

// connected components using union-find algorithm
// derived from connected2.cpp, cs453/adm/hw2

//int parent[MAXLABEL];   // the index of the parent node (0 if root)
//int plabel[MAXLABEL];   // consecutive labels of root nodes

// finds root label of tree by following parent links
int ccfind(int i, int *parent)
{
    int j = i;
    while (parent[j] != 0) {
        j = parent[j];
    }
    if (j != i)
        parent[i] = j; // for efficiency, update pointer
    return j;
}

// creates union by making second tree subtree of first
int ccunion(int i, int j, int *parent)
{
    //printf("unionizing %d, %d\n", i, j);
    int ii = ccfind(i, parent);
    int jj = ccfind(j, parent);
    if (ii != jj)
        parent[jj] = ii;
    return ii;
}

// extended union function that also handles the 0-label
int cccombine(int i, int j, int *parent) {
    if (i == 0)
        return j;
    else {
        if (j == 0)
            return i;
        else
            return ccunion(i, j, parent);
    }
}

// First version: connected components of target value UNK
// Compute connected components of band b in float image using integer image 'components' 
// using the union-find method.  Use numNeighbors (4 or 8) neighbors.  
// return a vector of all the componenents found.
vector<struct ccomp> computeUnkComponents(CFloatImage img, int b, CIntImage &components) {
    CShape sh = img.Shape();
    int w = sh.width, h = sh.height;
    sh.nBands = 1;
    components.ReAllocate(sh);

    float targetVal = UNK; // find holes
    int numNeighbors = 4;  // 4 or 8

    vector<int> parent;
    parent.push_back(0); // index 0 is not used

    int x, y;
    int label = 0;

    // first pass
    for (y = 0; y < h; y++) {
        for (x = 0; x < w; x++) {
            float val = img.Pixel(x, y, b);
            if (val == targetVal) {
		int *pp = &parent[0];
                int c1 = (x > 0 ? components.Pixel(x-1, y,   0) : 0);
                int c2 = (y > 0 ? components.Pixel(x,   y-1, 0) : 0);
                int c = cccombine(c1, c2, pp);
                if (numNeighbors == 8 && y > 0) {
                    int c3 = (x > 0   ? components.Pixel(x-1, y-1, 0) : 0);
                    int c4 = (x < w-1 ? components.Pixel(x+1, y-1, 0) : 0);
                    c = cccombine(c, c3, pp);
                    c = cccombine(c, c4, pp);
                }
                if (c == 0) { // new component
                    //parent[label] = 0;
                    label++;
		    parent.push_back(0); // new component at index label
                    components.Pixel(x, y, 0) = label;
                } else { // use combined label
                    components.Pixel(x, y, 0) = c;
                }
            } else { // val != targetVal
                components.Pixel(x, y, 0) = 0;  // not a component
	    }
	}
    }

    // count unique components:
    int n = 0;
    vector<int> plabel;
    plabel.resize(parent.size());
    struct ccomp emptycomp = {0, w, -1, h, -1};
    vector<struct ccomp> comp;
    comp.push_back(emptycomp); // index 0 is not used

    for (int i = 1; i <= label; i++)
        if (parent[i] == 0) {
            plabel[i] = ++n;
	    comp.push_back(emptycomp);
        }

    // second pass: process unions, assign consecutive labels, compute size and bbox
    for (y = 0; y < h; y++) {
        for (x = 0; x < w; x++) {
            int c = components.Pixel(x, y, 0);
            if (c > 0) {
		int k = plabel[ccfind(c, &parent[0])];
                components.Pixel(x, y, 0) = k;
		comp[k].n++;
		comp[k].x1 = min(x, comp[k].x1);
		comp[k].x2 = max(x, comp[k].x2);
		comp[k].y1 = min(y, comp[k].y1);
		comp[k].y2 = max(y, comp[k].y2);
	    }
	}
    }
    printf("found %d componenents\n", n-1);

    return comp;
}


// Second version: connected components of disparities, based on threshold on disp difference
// Compute connected components of band b in float image using integer image 'components' 
// using the union-find method.  Use 4 neighbors.  
// return a vector of all the components found.
// TODO: avoid code duplication....
vector<struct ccomp> computeDispComponents(CFloatImage img, int b, CIntImage &components, float thresh) {
    CShape sh = img.Shape();
    int w = sh.width, h = sh.height;
    sh.nBands = 1;
    components.ReAllocate(sh);

    vector<int> parent;
    parent.push_back(0); // index 0 is not used

    int x, y;
    int label = 0;

    // first pass
    for (y = 0; y < h; y++) {
        for (x = 0; x < w; x++) {
            float val = img.Pixel(x, y, b);
	    if (val != UNK) {
		float val1 = (x > 0 ? img.Pixel(x-1, y,   b) : UNK);
		float val2 = (y > 0 ? img.Pixel(x  , y-1, b) : UNK);
		int c = 0;
		int c1 = (x > 0 ? components.Pixel(x-1, y,   0) : 0);
		int c2 = (y > 0 ? components.Pixel(x,   y-1, 0) : 0);
		int *pp = &parent[0];
		if (fabs(val1 - val) <= thresh) // current pixel is connected to left
		    c = c1;
		if (fabs(val2 - val) <= thresh) // current pixel is connected to top
		    c = cccombine(c, c2, pp);
		if (c == 0) { // new component
		    //parent[label] = 0;
		    label++;
		    parent.push_back(0); // new component at index label
		    components.Pixel(x, y, 0) = label;
		} else { // use combined label
		    components.Pixel(x, y, 0) = c;
		}
            } else { // val == UNK
                components.Pixel(x, y, 0) = 0;  // not a component
	    }
	}
    }
    // rest is same as before; TODO: factor code

    // count unique components:
    int n = 0;
    vector<int> plabel;
    plabel.resize(parent.size());
    struct ccomp emptycomp = {0, w, -1, h, -1};
    vector<struct ccomp> comp;
    comp.push_back(emptycomp); // index 0 is not used

    for (int i = 1; i <= label; i++)
        if (parent[i] == 0) {
            plabel[i] = ++n;
	    comp.push_back(emptycomp);
        }

    // second pass: process unions, assign consecutive labels, compute size and bbox
    for (y = 0; y < h; y++) {
        for (x = 0; x < w; x++) {
            int c = components.Pixel(x, y, 0);
            if (c > 0) {
		int k = plabel[ccfind(c, &parent[0])];
                components.Pixel(x, y, 0) = k;
		comp[k].n++;
		comp[k].x1 = min(x, comp[k].x1);
		comp[k].x2 = max(x, comp[k].x2);
		comp[k].y1 = min(y, comp[k].y1);
		comp[k].y2 = max(y, comp[k].y2);
	    }
	}
    }
    printf("found %d components\n", n);

    return comp;
}




///////////////////////////////////////////////////////////////////////////
// line and plane fit

// plane fit z ~ ax + by + c, where x, y, z are given as vectors
void fitPlane(vector<float> vx, vector<float> vy, vector<float> vz, float &a, float &b, float &c)
{
    float s1=0, sx=0, sy=0, sz=0, sxx=0, sxy=0, sxz=0, syy=0, syz=0;
    for (int k = 0; k < (int)vx.size(); k++) {
	float x = vx[k];
	float y = vy[k];
	float z = vz[k];
	s1 += 1;
	sx += x;
	sy += y;
	sz += z;
	sxx += x * x;
	sxy += x * y;
	sxz += x * z;
	syy += y * y;
	syz += y * z;
    }
    float det = 1.0 / (sxx*syy*s1-sxx*sy*sy-sxy*sxy*s1+2.0*sxy*sx*sy-sx*sx*syy);
    a = det * ( (syy*s1-sy*sy)*sxz+(-sxy*s1+sx*sy)*syz+(sxy*sy-sx*syy)*sz );
    b = det * ( (-sxy*s1+sx*sy)*sxz+(sxx*s1-sx*sx)*syz+(-sxx*sy+sxy*sx)*sz );
    c = det * ( (sxy*sy-sx*syy)*sxz+(-sxx*sy+sxy*sx)*syz+(sxx*syy-sxy*sxy)*sz );
}
// I generated the above equations using the following Maple program:
// restart; with(linalg);
// A := matrix( 3, 3, [sxx, sxy, sx, sxy, syy, sy, sx, sy, s1]);
// d := det(A);
// B := evalm(d*inverse(A));
// z := matrix(3, 1, [sxz, syz, sz]);
// r := evalm(B&*z);
// readlib(C);
// C(d);
// C(r);











/* not used anymore:

// apply median filter.  use k=5 for 4-connected neighbors, k=9 for full 3x3 neighborhood
void median_filter(CByteImage src, CByteImage &dst, int k)
{
    CShape sh = src.Shape();
    int x, y, w = sh.width, h = sh.height;

    dst.ReAllocate(sh, false);

    for (y = 0; y < h; y++) {
        uchar *pm = &src.Pixel(0, y-1, 0);
        uchar *p = &src.Pixel(0, y, 0);
        uchar *pp = &src.Pixel(0, y+1, 0);
        uchar *res = &dst.Pixel(0, y, 0);

	if (y > 0 && y < h-1) {
	    for (x = 1; x < w-1; x++) {
		uchar n[9] = {pm[x], p[x-1], p[x], p[x+1], pp[x],   // cross
			      pm[x-1], pm[x+1],pp[x-1],pp[x+1]};	// diagonal
		res[x] = median(n, k);
	    }
	    res[0] = p[0];
	    res[w-1] = p[w-1];
	} else {
	    for (x = 0; x < w; x++) {
		res[x] = p[x];
	    }
	}
    }
}


// line fit to int array:  val(x) ~ ax + b, where x = 0..n-1
// if unk != 0,  ignore values with label unk
void fitLine(int* val, int n, int stride, float &a, float &b, int unk)
{
    int x;
    int s1=0;
    float sx=0, sy=0, sxx=0, sxy=0;

    for (x = 0; x < n; x++, val += stride) {
	int y = *val;
	if (y == unk)
	    continue;
	s1++;
	sx += x;
	sy += y;
	sxx += x * x;
	sxy += x * y;
    }
    float det = 1.0 / (s1 * sxx - sx * sx);
    a = det * ( s1 * sxy - sx * sy);
    b = det * (-sx * sxy + sxx * sy);
}
*/



///////////////////////////////////////////////////////////////////////////
// miscellaneous

// make sure a command-line argument is a non-negative integer
static void AssertIntString(char *s) {
    for (int k=0; s[k]; k++) {
	if (*s < '0' || *s > '9')
	    throw CError("Positive integer expected: '%s'", s);
    }
}

// safe parsing of integer argument
int atoiSafe(char *s) {
    AssertIntString(s);
    return atoi(s);
}


// written by Porter, modified by DS
float robustAverage(vector<float> nums, float maxdiff, int mingroup){
    std::sort(nums.begin(), nums.end());
    int stable =0;
    while((int)nums.size() != stable) {
	stable = nums.size();
	float median = nums[nums.size()/2];
	vector<float> close;
	//vector<float> far;

	for (int i =0; i < (int)nums.size(); i++) {
	    if (fabs(nums[i] - median) <= maxdiff)
		close.push_back(nums[i]);
	    //else
	    //far.push_back(nums[i]);
	}

	/*
	if(close.size() >= far.size()){
	    nums = close;
	}else{
	    nums = far;
	}
	*/
	nums = close; // DS: it makes no sense to me to ever use far...
    }

    if((int)nums.size() < mingroup)
	return UNK;

    float avg = 0;
    for(int i = 0; i < (int)nums.size(); i++)
	avg += nums[i];

    avg /= (int)nums.size();
    return avg;
}

/*
  int robustAverage(vector<int> nums, int maxdiff, int mingroup){
  std::sort(nums.begin(), nums.end());
  int stable =0;
  while((int)nums.size() != stable){
  stable = nums.size();
  int median = nums[nums.size()/2];
  //int median = nums[0];
  //maxdiff = 5;		
  vector<int> close;
  vector<int> far;

  for(int i =0; i < (int)nums.size(); i++){
  if(abs(nums[i] - median) <= maxdiff){
  close.push_back(nums[i]);
  }else{
  far.push_back(nums[i]);
  }
  }

  //if(close.size() >= far.size()){
  //	nums = close;
  //}else{
  //	nums = far;
  //}

  if (close.size() >= far.size() && close[0] < far[0]){
  nums = close;
  }else if (close.size() < far.size() && close[0] > far[0]){
  nums = far;
  }else if (close.size() >= far.size() && close[0] > far[0]){
  if (far.size() > mingroup)
  nums = far;
  else
  nums = close;
  }else{
  if (close.size() > mingroup)
  nums = close;
  else
  nums = far;
  }

  }
  if((int)nums.size() < mingroup){
  return NOMATCH;
  }
  int avg= 0;
  for(int i =0; i < (int)nums.size(); i++){
  avg += nums[i];
  }
  avg /= (int)nums.size();
  return avg;
  }

  // utility for adding a black frame around a pgm image
  // has nothing to do with grey decode, but was used to
  // create pictures for symcost paper
  void addFrame(CByteImage result) {
  CShape sh = result.Shape();
  int x, y, w = sh.width, h = sh.height;
	
  for (y = 0; y < h; y++) {
  uchar *r = &result.Pixel(0, y, 0);
		
  for (x = 0; x < w; x++) {
  if (x==0 || x==w-1 || y==0 || y==h-1)
  r[x] = 0;
  }
  }
  }

*/

CFloatImage mergeToFloImage(CFloatImage &x, CFloatImage &y)
{
    CShape sh = CShape(x.Shape().width, x.Shape().height, 2);
    CFloatImage merged(sh);

    for(int j = 0; j < sh.height; j++){
	for(int i = 0 ; i < sh.width; i++){
	    merged.Pixel(i,j,0) = x.Pixel(i,j,0);
	    merged.Pixel(i,j,1) = y.Pixel(i,j,0);
	}
    }

    return merged;
}

pair<CFloatImage, CFloatImage> splitFloImage(CFloatImage &merged)
{
    CShape sh = CShape(merged.Shape().width, merged.Shape().height, 1);
    CFloatImage x(sh);
    CFloatImage y(sh);

    for(int j = 0; j < sh.height; j++){
	for(int i = 0 ; i < sh.width; i++){
	    x.Pixel(i,j,0) = merged.Pixel(i,j,0);
	    y.Pixel(i,j,0) = merged.Pixel(i,j,1);
	}
    }
    return pair<CFloatImage, CFloatImage>(x,y);
}

void WriteBand(CFloatImage& img, int band, float scale, const char* filename, int verbose)
{
    CShape sh = img.Shape();
    sh.nBands = 1;
    CFloatImage dst(sh);
    for(int j = 0; j < sh.height; j++){
	for(int i = 0 ; i < sh.width; i++){
	    float v = img.Pixel(i, j, band);
	    if (v != UNK)
		v *= scale;
	    dst.Pixel(i, j, 0) = v;
	}
    }
    WriteImageVerb(dst, filename, verbose);
}


CFloatImage mergeToNBandImage(vector<CFloatImage*> imgs)
{
    CFloatImage merged;
    CShape sh = CShape(imgs[0]->Shape().width, imgs[0]->Shape().height, imgs.size());

    merged.ReAllocate(sh);
    merged.ClearPixels();

    for(int j = 0; j < sh.height; j++){
	for(int i = 0 ; i < sh.width; i++){
	    for(int k = 0 ; k < sh.nBands; k++){
		merged.Pixel(i,j,k) = imgs[k]->Pixel(i,j,0);
	    }
	}
    }
    return merged;
}

vector<CFloatImage> splitNBandImage(CFloatImage &merged)
{
    CShape sh = CShape(merged.Shape().width, merged.Shape().height, 1);
    int n = merged.Shape().nBands;

    vector<CFloatImage> imgs;

    for(int i = 0; i < n; i++){
	CFloatImage im;
	im.ReAllocate(sh);
	imgs.push_back(im);
   }

    for(int i = 0 ; i < sh.width; i++){
	for(int j = 0; j < sh.height; j++){
	    for(int k =0; k < n; k++){
		imgs[k].Pixel(i,j,0) = merged.Pixel(i,j,k);
	    }
	}
    }

    return imgs;
}


void ReadFlowFileVerb(CFloatImage& img, const char* filename, int verbose)
{
    if (verbose)
	fprintf(stderr, "Reading image %s\n", filename);
    ReadFlowFile(img, filename);
}

void WriteFlowFileVerb(CFloatImage img, const char* filename, int verbose)
{
    if (verbose)
	fprintf(stderr, "Writing image %s\n", filename);
    WriteFlowFile(img, filename);
}

/* no longer used

// Grey code functions

// encodes n to grey code
unsigned int greycodeOld(unsigned int n) {
    return  n ^ (n >> 1);
}

// decodes n from grey code
unsigned int invgreycodeOld(unsigned int n) {
    unsigned int r = 0;
    for (; n != 0; n >>= 1)
	r ^= n;
    return  r;
}

// returns i-th bit of grey coded number n
unsigned int greybit(unsigned int n, int i) {
    unsigned int g = greycodeOld(n);
    return  1 & (g >> i);
}

// test function to print grey codes
void testgreycode() {
    for (int n=0; n < 35; n++) {
        int g = greycodeOld(n);
	int g2 = invgreycodeOld(g);

        printf("%3d  %3d  %3d   ", n, g, g2);
        for (int j=9; j>=0; j--)
            printf("%d ", greybit(n, j));

        printf("\n");
    }
}

*/
