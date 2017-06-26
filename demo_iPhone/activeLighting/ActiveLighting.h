// from Main.cpp

int main(int argc, char *argv[]);
//int main2(int argc, char *argv[]);



/*
// prototypes:

// threshold images (defined in Threshold.cpp)
void threshold(char* outdir, char **imList, int numIm);

// decode images (defined in Decode.cpp)
CFloatImage decode(char* outdir, char* codefile, int direction, int eraseForeground, char* maskdir, char **imList, int numIm);
CFloatImage refine(char* outdir, int direction, char* decodedIm);

// combine multiple confidence maps into one (defined in Threshold.cpp)				
void combineConfidence(char *outfile, char **imList, int numIm, int certain);

// defined in Disparities.cpp
void computeDisparities(char *in0, char *in1, char *out0, char *out1, int dXmin, int dXmax, int dYmin, int dYmax);
void runCrossCheck(char *in0, char *in1, char *out0, char *out1, float thresh, int xonly, int halfocc);
void runFilter(char *srcfile, char *dstfile, float ythresh, int kx, int ky, int mincompsize, int maxholesize);
void mergeDisparityMaps(char* output, char** filenames, int count, int mingroup, float maxdiff);
void mergeDisparityMaps2(float maxdiff, int nV, int nR, char* outdfile, char* outsdfile, char* outnfile, char *inmdfile, char **invdfiles, char **inrdfiles);
void clipdisps(char* indfile, char* insdfile, char* innfile, char* outdfile, char* outsdfile, char* outnfile, float dmin, float dmax);
void maskdisps(char *indfile, char *outdfile, char *mfile);


// defined in Reproject.cpp
void reproject(char *dispFile, char *codeFile, char* outFile, char* errFile, char* matfile);

// defined in Calibrate.cpp
void calibrate(int pairsnum, int circles, char** left, char** right, int boardw, int boardh, float squaresize, int visualize, char* dirname);
void makeRectificationMaps(char* dirname, int w, int h, int w2, int h2);

// defined in Rectify.cpp
void rectify(int nimages, int w, int h, char* destdir, char** matrices, char** photos);
void createMask(char* outdir, int diffThresh, char** imList0, int numIm0);
void mergeMasks(char* outdir, char** imList, int mergeThresh, int numIm0);

*/
