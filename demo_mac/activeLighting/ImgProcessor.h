// Header file for selected image processing code from ActiveLighting
// created 06/28/2017 by Nicholas Mosier

#include "imageLib.h"
#include "flowIO.h"
#include "Utils.h"

void test(void);

CFloatImage refine(char *outdir, int direction, char* decodedIm);
void computeDisparities(char *in0, char *in1, char *out0, char *out1, int dXmin, int dXmax, int dYmin, int dYmax);
