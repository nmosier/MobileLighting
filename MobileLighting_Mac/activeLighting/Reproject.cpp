///////////////////////////////////////////////////////////////////////////
//
// NAME
//  Reproject.cpp -- compute projection matrix for new view and compute reprojected disparities
//
// DESCRIPTION
//  Takes a disparity map and the u, v code maps for an illumination direction, and
//  computes the projection matrix:
//
//  Input: 
//   - set of k scene points Si = [xi yi di 1]'
//   - coordinates of those points in new view Pi = [ui vi 1]'
//
//  Output: projection matrix M
//
//  Relationship: Pi = M Si  where M is unknown 4x3 projection matrix [m0 m1 m2]'
//  This gives two linear equations per point:
//    ui m2 Si = m0 Si
//    vi m2 Si = m1 Si
//  Which gives a large overconstrained system Ax ~ b where x is the vector of 
//  the 11 unknowns (we fix m23=1), and A is 2k x 11, and b is 2k x 1:
//
//  A=                                                           b=
//  x1  y1  d1  1   0   0   0   0   -x1*u1 -y1*u1 -d1*u1         u1
//  0   0   0   0   x1  y1  d1  1   -x1*v1 -y1*v1 -d1*v1         v1
//  ...                                                          ...
//
//  This is solved using least squares by solving A'Ax = A'b using Gauss elimination
//
//  The goodness of fit is then evaluated, and the outliers identified.  The fit is repeated
//  with smaller and smaller outlier threholds until a good fit is found.  The robustly 
//  estimated projection matrix is then used to translate the u,v values into disparities.
//
// Copyright � Daniel Scharstein, 2002.
// major change 2014: find outliers based on recovered disparities, not code values
//
///////////////////////////////////////////////////////////////////////////

#include <iostream>
#include "imageLib/imageLib.h"
#include "Utils.h"
#include "flowIO.h"
#include "opencv/cv.h"

// factors to divide x, y, u, and v by for improved numerical stability
#define SCALE  1000.0
#define VSCALE 1000.0    // try separate factor for v
#define DSCALE 100.0   // try separate factor for d

void writeMat(cv::Mat A, const char *fname)
{
    FILE *fp = fopen(fname, "w");
    for (int i = 0; i < A.rows; i++){
	for (int j = 0; j < A.cols; j++){
	    fprintf(fp, "%f\t", A.at<float>(i,j));
	}
	fprintf(fp, "\n");
    }
    fclose(fp);
}

// attempt at new version
void SolveProjectionCV(CFloatImage disp, CFloatImage codeu, CFloatImage codev, CByteImage badmap, double *M, int step)
{
    CShape sh = disp.Shape();
    int x, y, w = sh.width, h = sh.height;
    int verbose = 1;

    //if (step < 3) 
    //step = 3;  // always use median over 3x3 windows, so no smaller step size allowed

    if (verbose) printf("building matrix (step=%d)\n", step);

    // count unknowns:
    int cntd = 0;
    int cntc = 0;
    int cnt = 0;
    cv::Mat A;
    vector<float> bvec;
    // estimate the matrix
//    WriteImageVerb(badmap, "/Users/nicholas/Desktop/badmap.pgm", 1);

    
    for (y = step; y < h-step; y += step) {
	uchar *bad = &badmap.Pixel(0, y, 0);
        
	for (x=step; x < w-step; x += step) {
	    if (bad[x])		// used for robust fit
		continue;

	    float d = disp.Pixel(x, y, 0);
	    float u = codeu.Pixel(x, y, 0);
	    float v = codev.Pixel(x, y, 0);

	    // abandonded median filter idea, didn't work out
	    //float d = median3x3(disp, x, y); // median seems to be ok for disparities
	    //float u = median3x3(codeu, x, y); // ..but NOT for code values!
	    //float v = median3x3(codev, x, y);

	    cnt++;

	    if (d == UNK )
		cntd++;

	    if (u == UNK || v == UNK)
		cntc++;

	    if (d == UNK || u == UNK || v == UNK )
		continue;

	    d /= DSCALE;
	    u /= SCALE;
	    v /= VSCALE;
	    float xx = x / SCALE;
	    float yy = y / SCALE;

	    cv::Mat Arow(2,11,CV_32FC1);

	    // even row (first equation)
	    Arow.at<float>(0,0) =  xx;   Arow.at<float>(0,1) =  yy;   Arow.at<float>(0,2) =   d; Arow.at<float>(0,3) = 1;
	    Arow.at<float>(0,4) =   0;   Arow.at<float>(0,5) =   0;   Arow.at<float>(0,6) =   0; Arow.at<float>(0,7) = 0;
	    Arow.at<float>(0,8) = -xx*u; Arow.at<float>(0,9) = -yy*u; Arow.at<float>(0,10) = -d*u;
	    bvec.push_back(u);

	    // odd row (second equation)
	    Arow.at<float>(1,0) =   0;   Arow.at<float>(1,1) =   0;   Arow.at<float>(1,2) =   0; Arow.at<float>(1,3) = 0;
	    Arow.at<float>(1,4) =  xx;   Arow.at<float>(1,5) =  yy;   Arow.at<float>(1,6) =   d; Arow.at<float>(1,7) = 1;
	    Arow.at<float>(1,8) = -xx*v; Arow.at<float>(1,9) = -yy*v; Arow.at<float>(1,10) = -d*v;
	    bvec.push_back(v);

	    if(A.cols == 0){
		A = Arow;
	    }else{
		A.push_back(Arow);
	    }
	}
    }

    if (verbose)
	printf("unknown d: %.2f%%, unknown code: %.2f%%\n", 100.0*cntd/cnt, 100.0*cntc/cnt);
    if (/* DISABLES CODE */ (0) && verbose) printf("solving matrix\n");

    cv::Mat b(bvec);

    cv::Mat sol;
    cv::solve(A,b,sol,cv::DECOMP_LU | cv::DECOMP_NORMAL);  // seems to work more reliably and faster than SVD
//    cv::solve(A,b,sol,cv::DECOMP_SVD);
    //cv::solve(A,b,sol,cv::DECOMP_QR);
    printf("A: %d x %d\n", A.rows, A.cols);
    //printf("b: %d x %d\n", b.rows, b.cols);
    //printf("sol: %d x %d\n", sol.rows, sol.cols);
    for(int i = 0 ;i < sol.rows; i++){
	for(int j = 0; j < sol.cols; j++){
	    M[i*sol.cols+j] = sol.at<float>(i,j);
	}
    }

    M[11] = 1;


    if (verbose) {
	printf("projection matrix M:\n");
	for (int i=0; i<3; i++) {
	    for (int j=0; j<4; j++)
		printf("%12.6f  ", M[i*4+j]);
	    printf("\n");
	}
    }
    //writeMat(A, "Amat.txt");
    //writeMat(b, "bmat.txt");
    //writeMat(sol, "smat.txt");
    //exit(1);
}

// old version
void SolveProjectionCV_old(CFloatImage disp, CFloatImage codeu, CFloatImage codev, CByteImage badmap, double *M, int step)
{
    CShape sh = disp.Shape();
    int x, y, w = sh.width, h = sh.height;
    int verbose = 1;

    //if (verbose) printf("building matrix (step=%d)\n", step);

    // count unknowns:
    int cntd = 0;
    int cntc = 0;
    int cnt = 0;
    cv::Mat A;
    vector<float> bvec;
    // estimate the matrix
    for (y = 0; y < h; y += step) {
	float *dis = &disp.Pixel(0, y, 0);
	float *cu = &codeu.Pixel(0, y, 0);
	float *cv = &codev.Pixel(0, y, 0);
	uchar *bad = &badmap.Pixel(0, y, 0);
        
	for (x=0; x < w; x += step) {
	    if (bad[x])		// used for robust fit
		continue;

	    float d = dis[x];
	    float u = cu[x];
	    float v = cv[x];

	    cnt++;

	    if (d == UNK )
		cntd++;

	    if (u == UNK || v == UNK)
		cntc++;

	    if (d == UNK || u == UNK || v == UNK )
		continue;

	    cv::Mat Arow(2,11,CV_32FC1);

	    // even row (first equation)
	    Arow.at<float>(0,0) =  x; Arow.at<float>(0,1) =  y; Arow.at<float>(0,2) =  d; Arow.at<float>(0,3) =  1;
	    Arow.at<float>(0,4) =  0; Arow.at<float>(0,5) =  0; Arow.at<float>(0,6) =  0; Arow.at<float>(0,7) =  0;
	    Arow.at<float>(0,8) =  -x*u; Arow.at<float>(0,9) =  -y*u; Arow.at<float>(0,10) =  -d*u;
	    bvec.push_back(u);

	    // odd row (second equation)
	    Arow.at<float>(1,0) =  0; Arow.at<float>(1,1) =  0; Arow.at<float>(1,2) =  0; Arow.at<float>(1,3) =  0;
	    Arow.at<float>(1,4) =  x; Arow.at<float>(1,5) =  y; Arow.at<float>(1,6) =  d; Arow.at<float>(1,7) =  1;
	    Arow.at<float>(1,8) =  -x*v; Arow.at<float>(1,9) =  -y*v; Arow.at<float>(1,10) =  -d*v;

	    bvec.push_back(v);

	    if(A.cols == 0){
		A = Arow;
	    }else{
		A.push_back(Arow);
	    }
	}
    }

    if (verbose)
	printf("unknown d: %.2f%%, unknown code: %.2f%%\n", 100.0*cntd/cnt, 100.0*cntc/cnt);
    if (/* DISABLES CODE */ (0) && verbose) printf("solving matrix\n");

    cv::Mat b(bvec);

    cv::Mat sol;
    cv::solve(A,b,sol,cv::DECOMP_LU | cv::DECOMP_NORMAL);
    for(int i = 0 ;i < sol.rows; i++){
	for(int j = 0; j < sol.cols; j++){
	    M[i*sol.cols+j] = sol.at<float>(i,j);
	}
    }

    M[11] = 1;


    if (verbose) {
	printf("projection matrix M:\n");
	for (int i=0; i<3; i++) {
	    for (int j=0; j<4; j++)
		printf("%12.6f  ", M[i*4+j]);
	    printf("\n");
	}
    }
}

// reproject a disparity map based on the recovered projection matrix
void projectDisp(CFloatImage codeu, CFloatImage codev, CFloatImage ndisp, double *M)
{
    CShape sh = codeu.Shape();
    int x, y, w = sh.width, h = sh.height;
    double *M0 = &M[0];
    double *M1 = &M[4];
    double *M2 = &M[8];

    for (y = 0; y < h; y++) {
	float *cu = &codeu.Pixel(0, y, 0);
	float *cv = &codev.Pixel(0, y, 0);
	float *d = &ndisp.Pixel(0, y, 0);

	for (x=0; x < w; x++) {
	    float u = cu[x];
	    float v = cv[x];
	    if (u == UNK || v == UNK) {
		d[x] = UNK;
	    } else {
		// do least squares combination of the two estimates for d
		u /= SCALE;
		v /= VSCALE;
		float xx = x / SCALE;
		float yy = y / SCALE;

		double bu = xx * (M2[0]*u - M0[0]) + yy * (M2[1]*u - M0[1]) + (M2[3]*u - M0[3]);
		double bv = xx * (M2[0]*v - M1[0]) + yy * (M2[1]*v - M1[1]) + (M2[3]*v - M1[3]);
		double au =    - (M2[2]*u - M0[2]);
		double av =    - (M2[2]*v - M1[2]);

		double dd = (au * bu + av * bv) / (au * au + av * av);
		//double dd =  bu / au;
		d[x] = (float) dd * DSCALE;
	    }
	}
    }
}


// NEW: evaluate fit based on how well d is reconstructed
// mark all pixels whose error is larger than maxerr in badmap
void EvaluateFit(CFloatImage disp, CFloatImage codeu, CFloatImage codev, CByteImage badmap, double *M, float maxerr)
{
    CShape sh = disp.Shape();
    CFloatImage ndisp(sh);
    int x, y, w = sh.width, h = sh.height;
    int verbose = 1;

    int cnt = 0;
    int badcnt = 0;
    double sd = 0;

    projectDisp(codeu, codev, ndisp, M);
    badmap.ClearPixels();

    for (y = 0; y < h; y++) {
	float *dis = &disp.Pixel(0, y, 0);
	float *ndis = &ndisp.Pixel(0, y, 0);
	uchar *bad = &badmap.Pixel(0, y, 0);
	
	for (x=0; x < w; x++) {
	    float d = dis[x];
	    float nd = ndis[x];
			
	    if (d == UNK || nd==UNK)
		continue;
	
	    cnt++;
	    float dd = d - nd;
	    if (fabs(dd) > maxerr) {
		badcnt++;
		bad[x] = 1;		// mark as bad pixel for subsequent passes
	    } else
		sd += dd * dd;
	}
    }
    if (verbose) 
	printf("rmstot=%6.2f, rmsgood=%6.2f,  bad=%5.2f%% (bad thresh= %g)\n",
	       sqrt(sd/cnt), sqrt(sd/(cnt-badcnt)), 100.0*badcnt/cnt, maxerr);
}


// OLD -- evaluate fit based on (u, v)
// evaluate goodness of fit of projection matrix M for disparity map and u and v code 
// value maps, and mark all pixels whose error is larger than maxerr in badmap
void EvaluateFit_old(CFloatImage disp, CFloatImage codeu, CFloatImage codev, CByteImage badmap, double *M, double maxerr)
{
    CShape sh = disp.Shape();
    int x, y, w = sh.width, h = sh.height;
    int i, j;
    int verbose = 1;
    double suu = 0, svv = 0;
    int badu = 0, badv = 0;
    int cnt = 0;

    double maxerrv = 10 * maxerr;
	
    badmap.ClearPixels();

    for (y = 0; y < h; y++) {
	float *dis = &disp.Pixel(0, y, 0);
	float *cu = &codeu.Pixel(0, y, 0);
	float *cv = &codev.Pixel(0, y, 0);
	uchar *bad = &badmap.Pixel(0, y, 0);
	
	for (x=0; x < w; x++) {
	    float d = dis[x];
	    float u = cu[x];
	    float v = cv[x];
			
	    if (d == UNK || u==UNK || v == UNK)
		continue;
	
	    cnt++;
			
	    double S[4] = {x/SCALE, y/SCALE, d/DSCALE, 1};
	    double P[3] = {0, 0, 0};
			
	    // project S by computing X = M S
	    for (i=0; i<3; i++) {
		for (j=0; j<4; j++)
		    P[i] += M[4*i + j] * S[j];
	    }
			
	    double nu = SCALE * P[0] / P[2];
	    double nv = VSCALE * P[1] / P[2];
	    double du = nu - u;
	    double dv = nv - v;
	    if (fabs(du) > maxerr) {
		badu++;
		bad[x] = 1;		// mark as bad pixel for subsequent passes
	    } else
		suu += du * du;

	    if (fabs(dv) > maxerrv) {
		badv++;
		bad[x] = 1;		// mark as bad pixel for subsequent passes
	    } else
		svv += dv * dv;
	}
    }
    if (verbose) 
	printf("rmsu= %5.2f, rmsv= %5.2f, badu= %5.2f%%, badv= %5.2f%%  (bad thresh= %g)\n",
	       sqrt(suu/(cnt-badu)), sqrt(svv/(cnt-badv)), 100.0*badu/cnt, 100.0*badv/cnt, maxerr);

}



//compare two disparity maps and report statistics
void compareDisp(const char *str, CFloatImage disp0, CFloatImage disp1, float badThresh, char *errFile, FILE *log)
{
    CShape sh = disp0.Shape();
    int x, y, w = sh.width, h = sh.height;
    int verbose = 1;

    int cntBad = 0;
    int cnt = 0;
    float sd = 0;
    CFloatImage err(sh);
    
    for (y = 0; y < h; y++) {
	float *d0 = &disp0.Pixel(0, y, 0);
	float *d1 = &disp1.Pixel(0, y, 0);
	float *e = &err.Pixel(0, y, 0);

	for (x=0; x < w; x++) {
	    e[x] = UNK;

	    if (d0[x] == UNK || d1[x] == UNK)
		continue;

	    cnt++;
	    float diff = d0[x] - d1[x];
	    sd += diff * diff;

	    if (fabs(diff) > badThresh)
		cntBad++;
	    e[x] = diff;
	}
    }

    char buffer[200];
    sprintf(buffer, "%s: compared: %5.2f   rms: %5.2f   bad: %5.2f   badthresh: %g\n",
	       str, 100.0*cnt/(w*h), sqrt(sd/cnt), 100.0*cntBad/cnt, badThresh);
    fprintf(log, "%s", buffer);
    if (verbose)
        printf("%s", buffer);
    
    if (errFile != NULL)
	WriteImageVerb(err, errFile, verbose);
}

// invalidate pixels that were identfied as outliers
// ************ TODO
// need to mark the pixels with large residuals as bad in the original disparity map too!
// also should figure out where the errors get too big, and then don't fill occluded regions there either...?
// *** update: might not be necessary any more... now that we have perfect rectification, many outliers are
// already removed based on ydisps > 0.5
void removeBad(CFloatImage ndisp, CByteImage badmap)
{
    CShape sh = ndisp.Shape();
    int x, y, w = sh.width, h = sh.height;

    for (y = 0; y < h; y++) {
	float *d = &ndisp.Pixel(0, y, 0);
	uchar *bad = &badmap.Pixel(0, y, 0);
	for (x=0; x < w; x++) {
	    if (bad[x]) {
		d[x] = UNK;
	    }
	}
    }
}

// takes disparity map and two code maps and recovers projection matrix for projector
// then reprojects projector's disparities into camera disparities
//void reproject(char *dispFile, char *codeFile, char* outFile, char* errFile, char* matfile)
CFloatImage reproject(CFloatImage dispflo, CFloatImage codeflo, char* errFile, char* matfile, char *logfile)
{
    CFloatImage disp,dispboth,code,codex,codey;
    CShape sh;

    double M[12]; // projection matrix

//    ReadFlowFile(dispboth, dispFile);
    pair<CFloatImage, CFloatImage> d = splitFloImage(dispflo);
    disp = d.first;

//    ReadFlowFile(code, codeFile);
    pair<CFloatImage, CFloatImage> p = splitFloImage(codeflo);
    codex = p.first;
    codey = p.second;

    sh = disp.Shape();
    printf("sh=%dx%d\n", sh.width, sh.height);

    CByteImage badmap(sh);
    badmap.ClearPixels();
    int step;
    float maxerr;


    /*
    step = 6;     SolveProjectionCV(disp, codex, codey, badmap, M, step);
    maxerr = 5;   EvaluateFit(disp, codex, codey, badmap, M, maxerr);
    step = 6;     SolveProjectionCV(disp, codex, codey, badmap, M, step);
    maxerr = .5;  EvaluateFit(disp, codex, codey, badmap, M, maxerr);
    step = 6;     SolveProjectionCV(disp, codex, codey, badmap, M, step);
    maxerr = .25; EvaluateFit(disp, codex, codey, badmap, M, maxerr);
    step = 3;     SolveProjectionCV(disp, codex, codey, badmap, M, step);
    maxerr = 1;   EvaluateFit(disp, codex, codey, badmap, M, maxerr);
    */

    // old schedule:
    
    step = 3;    SolveProjectionCV(disp, codex, codey, badmap, M, step);
    maxerr = 40; EvaluateFit(disp, codex, codey, badmap, M, maxerr);
    step = 2;    SolveProjectionCV(disp, codex, codey, badmap, M, step);
    maxerr = 5;  EvaluateFit(disp, codex, codey, badmap, M, maxerr);
    step = 2;    SolveProjectionCV(disp, codex, codey, badmap, M, step);
    //maxerr = 3;  EvaluateFit(disp, codex, codey, badmap, M, maxerr);
    //step = 1;    SolveProjectionCV(disp, codex, codey, badmap, M, step);
    //maxerr = 3;  EvaluateFit(disp, codex, codey, badmap, M, maxerr);
    //step = 1;    SolveProjectionCV(disp, codex, codey, badmap, M, step);
    maxerr = 2;  EvaluateFit(disp, codex, codey, badmap, M, maxerr);
    step = 1;    SolveProjectionCV(disp, codex, codey, badmap, M, step);
    maxerr = 1;  EvaluateFit(disp, codex, codey, badmap, M, maxerr);



    // write projection matrix to screen and to matfile

    FILE *fp = fopen(matfile, "w");

    printf("=======Matrix========\n");
    for(int i =0; i < 3; i++){
	for(int j = 0; j < 4; j++){
	    printf("%f ",M[4*i+j]);
	    fprintf(fp, "%.12lf ",M[4*i+j]);
	}
	printf("\n");
	fprintf(fp, "\n");
    }

    fclose(fp);
    printf("Wrote %s\n", matfile);

    CFloatImage ndisp(sh);
    CFloatImage blank;
    blank.ReAllocate(sh);
    blank.FillPixels(UNK);

    FILE *log = fopen(logfile, "w");
    
    projectDisp(codex, codey, ndisp, M);
    compareDisp("before", disp, ndisp, 1.0, NULL, log);
    removeBad(ndisp, badmap);
    compareDisp("after ", disp, ndisp, 1.0, errFile, log);
    ndisp = mergeToFloImage(ndisp,blank);

    fclose(log);
    return ndisp;
}
