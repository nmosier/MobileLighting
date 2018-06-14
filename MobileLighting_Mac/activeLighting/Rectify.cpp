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
/*
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
	
 
		std::cout << "intrinsics:" << std::endl << k0 << std::endl << k1 << std::endl;
		std::cout << "distort:" << std::endl << d0 << std::endl << d1 << std::endl;
		std::cout << "rotate:" << std::endl << r << std::endl;
		std::cout << "projection:" << std::endl << t << std::endl;
 

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
*/

// computemaps -- computes maps for stereo rectification based on intrinsics & extrinsics matrices
// only needs to be computed once per stereo pair

Mat mapx0, mapy0;
Mat mapx1, mapy1;

void computemaps(int width, int height, char *intrinsics, char *extrinsics)
{
    cv::Size ims(width, height);
    std::clog << "computing maps " << ims << std::endl;
    FileStorage fintr(intrinsics, FileStorage::READ);
    FileStorage fextr(extrinsics, FileStorage::READ);
    Mat k,d,rect0,rect1,proj0,proj1;
    std::clog << "reading camera matrices..." << std::endl;
    fintr["Camera_Matrix"] >> k;
    fintr["Distortion_Coefficients"] >> d;
    fextr["Rectification_Parameters"]["Rectification_Transformation_1"] >> rect0;
    fextr["Rectification_Parameters"]["Projection_Matrix_1"] >> proj0;
    fextr["Rectification_Parameters"]["Rectification_Transformation_2"] >> rect1;
    fextr["Rectification_Parameters"]["Projection_Matrix_2"] >> proj1;
    std::clog << "read camera matrices" << std::endl;
    std::clog << "undistorting first maps..." << std::endl;
    initUndistortRectifyMap(k, d, rect0, proj0, ims, CV_32FC1, mapx0, mapy0);
    std::clog << "undistorting second maps..." << std::endl;
    initUndistortRectifyMap(k, d, rect1, proj1, ims, CV_32FC1, mapx1, mapy1);
    std::clog << "done computing maps" << mapx0.size() << std::endl;
}

extern "C" void rectifyDecoded(int camera, char *impath, char *outpath)
{
    printf("rectifying decoded image...");
    Mat image, im_linear, im_nearest, image2;
    Mat mapx, mapy;
    const float maxdiff = 0.5;
    const int imtype = CV_32FC1;
    
    ReadFilePFM(image, string(impath));
    cv::Size ims = image.size();
    
    image2 = Mat(ims, imtype, 1);
    im_linear = Mat(ims, imtype, 1);
    im_nearest = Mat(ims, imtype, 1);
    remap(image, im_linear, mapx, mapy, INTER_LINEAR);
    remap(image, im_nearest, mapx, mapy, INTER_NEAREST);
    
    for (int j = 0; j < ims.height; ++j) {
        for (int i = 0; i < ims.width; ++i) {
            float val_linear = im_linear.at<float>(j,i);
            float val_nearest = im_nearest.at<float>(j,i);
            float val;
            if (val_linear != INFINITY && fabs(val_linear - val_nearest) <= maxdiff) {
                val = val_linear;
            } else {
                val = val_nearest;
            }
            image2.at<float>(j,i) = val;
        }
    }

    WriteFilePFM(image2, outpath, 1);
}
