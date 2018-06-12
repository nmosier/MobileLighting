/*
 * Rectify.cpp
 *
 *  Created on: Jun 28, 2011
 *      Author: wwestlin
 *
 * DS 2/3/2014  -- added "justcopy" option if passing in '-' for matrix filenames
 * DS 3/21/2014 -- added w, h parameters to control the size of the output images
 * NM 6/2018 -- modified to run
 */

#include <iostream>
#include <opencv2/core/core.hpp>
#include <opencv2/highgui/highgui.hpp>
#include <opencv2/imgproc/imgproc.hpp>
#include <opencv2/calib3d/calib3d.hpp>
#include <string>
#include "pfmLib/ImageIOpfm.h"
#include "assert.h"

using namespace cv;

void rectify(int nimages, int camera, int w, int h, char* destdir, char** matrices, char** photos)
{
    Mat image, image2, mapx, mapy;
	const int nmatrices = 7;
    int justcopy = 0; // do actual rectification

    // assume valid matrix files unless first one starts with '-'
    if (matrices[0][0] == '-') {

		printf("NO RECTIFICATION -- just copying files\n");
		justcopy = 1;

    } else {

		Mat d0,d1,k0,k1,r,t;
	
		FileStorage(matrices[0], FileStorage::READ)["K0"] >> k0;
		FileStorage(matrices[1], FileStorage::READ)["K1"] >> k1;
		FileStorage(matrices[2], FileStorage::READ)["D0"] >> d0;
		FileStorage(matrices[3], FileStorage::READ)["D1"] >> d1;
		FileStorage(matrices[4], FileStorage::READ)["R"] >> r;
		FileStorage(matrices[5], FileStorage::READ)["T"] >> t;
	
		/*
		std::cout << "intrinsics:" << std::endl << k0 << std::endl << k1 << std::endl;
		std::cout << "distort:" << std::endl << d0 << std::endl << d1 << std::endl;
		std::cout << "rotate:" << std::endl << r << std::endl;
		std::cout << "projection:" << std::endl << t << std::endl;
		*/

		Size ims;

		if (w == 0 || h == 0) { // get image size from first image
		    image = imread(photos[0]);
		    ims = image.size();
		} else {
		    ims = Size(w, h); // specify output image size
		}


	//rectification map images
		mapx = Mat(ims, CV_32F, 1);
		mapy = Mat(ims, CV_32F, 1);
			
		Mat rect0, rect1, proj0, proj1, q;
		stereoRectify(k0, d0, k1, d1, ims, r, t, rect0, rect1, proj0, proj1, q);
		Mat intr = camera ? k1 : k0;
		Mat dist = camera ? d1 : d0;
		Mat rect = camera ? rect1 : rect0;
		Mat proj = camera ? proj1 : proj0;
		initUndistortRectifyMap(intr, dist, rect, proj, ims, CV_32FC1, mapx, mapy);
    }
    
    //Load image, remap, save to file
    for(int i = 0; i < nimages; i++) {

		image = imread(photos[i]);
	
		if (justcopy) {
		    image2 = image; // skip the actual rectification and just copy the image
		} else {
			const int imtype = CV_8UC1;	// if decoded, use 1-channel 32-bit floating point; otherwise, 1-channel 8-bit grayscale
			image2 = Mat(mapx.size(), imtype, 1);// cvCreateImage(cvGetSize(mapx), IPL_DEPTH_8U, 3);
		    remap(image, image2, mapx, mapy, INTER_LINEAR);
		}

		char buffer[1024];
		sprintf(buffer,"%s/image%.3d.pgm",destdir,i);
		imwrite(buffer, image2);
		if(i%2 == 0){
		    printf(".");
		    fflush(stdout);
		}
    }
    printf("\n");
}

void rectifyDecoded(int nimages, int camera, char* destdir, char** matrices, char** photos)
{
	Mat image, image2, mapx, mapy;
	const int nmatrices = 4;
    int justcopy = 0; // do actual rectification

    // assume valid matrix files unless first one starts with '-'
    if (matrices[0][0] == '-') {

		printf("NO RECTIFICATION -- just copying files\n");
		justcopy = 1;

    } else {

		Mat k,d,r,t;
	
		FileStorage(matrices[0], FileStorage::READ)["K"] >> k; // intrisnic matrix
		FileStorage(matrices[1], FileStorage::READ)["D"] >> d; // distortion matrix
		FileStorage(matrices[2], FileStorage::READ)["R"] >> r;
		FileStorage(matrices[3], FileStorage::READ)["T"] >> t;
		
        ReadFilePFM(image, string(photos[0]));
        Size ims = image.size();

        //rectification map images
		mapx = Mat(ims, CV_32F, 1);
		mapy = Mat(ims, CV_32F, 1);
			
		Mat rect0, rect1, proj0, proj1, q;
		stereoRectify(k, d, k, d, ims, r, t, rect0, rect1, proj0, proj1, q);
        Mat intr = k;
        Mat dist = d;
		Mat rect = camera ? rect1 : rect0;
		Mat proj = camera ? proj1 : proj0;
		initUndistortRectifyMap(intr, dist, rect, proj, ims, CV_32FC1, mapx, mapy);
    }
    
    //Load image, remap, save to file
    for(int i = 0; i < nimages; i++) {

		//image = imread(photos[i]);
		ReadFilePFM(image, string(photos[i]));
	
		if (justcopy) {
		    image2 = image; // skip the actual rectification and just copy the image
		} else {
			const int imtype = CV_32FC1;	// if decoded, use 1-channel 32-bit floating point; otherwise, 1-channel 8-bit grayscale
			image2 = Mat(mapx.size(), imtype, 1);// cvCreateImage(cvGetSize(mapx), IPL_DEPTH_8U, 3);
		    remap(image, image2, mapx, mapy, INTER_LINEAR);
		}

		char buffer[1024];
		sprintf(buffer,"%s/result%d-rectified.pfm",destdir, i);
		WriteFilePFM(image2, buffer, 1);
		if(i%2 == 0){
		    printf(".");
		    fflush(stdout);
		}
    }
    printf("\n");

}
