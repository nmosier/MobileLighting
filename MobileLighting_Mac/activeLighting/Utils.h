///////////////////////////////////////////////////////////////////////////
//
// NAME
//  Utils.h -- utility functions associated with active lighting project
//
// SEE ALSO
//  Utils.cpp             Implementation
//
// Copyright � Daniel Scharstein, 2002.
//
// updated 1/2014
//
///////////////////////////////////////////////////////////////////////////

#include <vector>
#include <math.h>

#define UNK INFINITY	// label for unknown pixel in Float image (used both for code values and disparities)

#define ABS(x) ((x) >= 0 ? (x) : (-(x)))


// color encoding

// map f from 0.0 .. 1.0 to hue (Red-Yellow-Green-Cyan-Blue-Magenta)
void hue(float f, uchar *rgb);

// given value f = -1..1, adjusts rgb values to black for f=-1 and white for f=1
void adjust_brightness(float f, uchar *rgb);

// map f from 0.0 .. 1.0 to spiral in Hue-Brightness space
void hueshade(float f, uchar *rgb, float rounds=100.0);

// filtering


// median of vector of floats; if vector is empty, return UNK
float median(vector<float> v);
// same, but returns average of center two elts for even length
float median2(float* v, int n);

// median over 3x3 window centered at x, y; assumes no bound check necessary
float median3x3(CFloatImage &im, int x, int y);

// k x k median filter of band b in float image, assume k is odd
void medianfilter(CFloatImage src, CFloatImage &dst, int k, int b);


// connected components

struct ccomp
{
    int n;               // num pixels
    int x1, x2, y1, y2;  // bounding box
};

// First version: connected components of target value UNK
vector<struct ccomp> computeUnkComponents(CFloatImage img, int b, CIntImage &components);

// Second version: connected components of disparities, based on threshold on disp difference
vector<struct ccomp> computeDispComponents(CFloatImage img, int b, CIntImage &components, float thresh);

// miscellaneous

// safe parsing of integer argument
int atoiSafe(char *s);

float robustAverage(vector<float> nums, float maxdiff, int mingroup);

//Combine 2 single channel float image into one .flo image
CFloatImage mergeToFloImage(CFloatImage &x, CFloatImage &y);

// split .flo image into to float images
pair<CFloatImage,CFloatImage> splitFloImage(CFloatImage &merged);

// save one band of a flo image
void WriteBand(CFloatImage& img, int band, float scale, const char* filename, int verbose);


// plane fit z ~ ax + by + c, where x, y, z are given as vectors
void fitPlane(vector<float> vx, vector<float> vy, vector<float> vz, float &a, float &b, float &c);


void ReadFlowFileVerb(CFloatImage& img, const char* filename, int verbose);
void WriteFlowFileVerb(CFloatImage img, const char* filename, int verbose);

CFloatImage mergeToNBandImage(vector<CFloatImage*> imgs);
vector<CFloatImage> splitNBandImage(CFloatImage &merged);
