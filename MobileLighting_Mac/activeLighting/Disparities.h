void computeDisparities(CFloatImage &fim0, CFloatImage &fim1, CFloatImage &fout0, CFloatImage &fout1, int dXmin, int dXmax, int dYmin, int dYmax);
pair<CFloatImage,CFloatImage> runCrossCheck(CFloatImage d0, CFloatImage d1, float thresh, int xonly, int halfocc);
//CFloatImage runFilter(CFloatImage img, float ythresh, int kx, int ky, int mincompsize, int maxholesize);
CFloatImage runFilter(CFloatImage img, float ythresh, int kx, int ky, int mincompsize, int maxholesize, char *debugdir = NULL);
CFloatImage mergeDisparityMaps(CFloatImage images[], int count, int mingroup, float maxdiff);
void mergeDisparityMaps2(float maxdiff, int nV, int nR, char* outdfile, char* outsdfile, char* outnfile, char *inmdfile, char **invdfiles, char **inrdfiles);
