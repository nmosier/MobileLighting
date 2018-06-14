// Header file for selected image processing code from ActiveLighting
// created 06/28/2017 by Nicholas Mosier

#include "imageLib/imageLib.h"
//#include "flowIO.h"
//#include "Rectify.hpp"
//#include "Utils.h"

CFloatImage refine(char *outdir, int direction, char* decodedIm, double angle);
void computeDisparities(CFloatImage &fim0, CFloatImage &fim1, CFloatImage &fout0, CFloatImage &fout1, int dXmin, int dXmax, int dYmin, int dYmax);
