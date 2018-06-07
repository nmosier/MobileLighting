/*
 * Rectify.cpp
 *
 *  Created on: Jun 28, 2011
 *      Author: wwestlin
 *
 * DS 2/3/2014  -- added "justcopy" option if passing in '-' for matrix filenames
 * DS 3/21/2014 -- added w, h parameters to control the size of the output images
 * 
 * edited by Nicholas Mosier on 06/07/2018
 */

#include <opencv/cv.h>
#include <opencv/highgui.h>
#include "string.h"

// using namespace cv;

void rectify(int nimages, int w, int h, char* destdir, char** matrices, char** photos)
{
    IplImage* image = NULL;
    IplImage* image2 = NULL;
    IplImage* mapx = NULL;
    IplImage* mapy = NULL;
    //cvMat image, image2, mapx, mapy;

    int justcopy = 0; // do actual rectification

    // assume valid matrix files unless first one starts with '-'
    if (matrices[0][0] == '-') {

	printf("NO RECTIFICATION -- just copying files\n");
	justcopy = 1;

    } else {

	//Load matrices from file

	CvMat* intrinsic = (CvMat*)cvLoad(matrices[0]);
	CvMat* distort = (CvMat*)cvLoad(matrices[1]);
	CvMat* rotate  = (CvMat*)cvLoad(matrices[2]);
	CvMat* projection  = (CvMat*)cvLoad(matrices[3]);

	CvSize ims;
	if (w == 0 || h == 0) { // get image size from first image
	    image = cvLoadImage(photos[0]);
	    ims = cvGetSize(image);
	} else {
	    ims = cvSize(w, h); // specify output image size
	}

	//rectification map images
	mapx = cvCreateImage(ims, IPL_DEPTH_32F, 1);
	mapy = cvCreateImage(ims, IPL_DEPTH_32F, 1);

	cvInitUndistortRectifyMap(intrinsic, distort, rotate, projection, mapx, mapy);
    }

    //Load image, remap, save to file
    for(int i = 0; i < nimages; i++){

	image = cvLoadImage(photos[i]);
	
	if (justcopy) {
	    image2 = image; // skip the actual rectification and just copy the image
	} else {
	    if (image2 == NULL) 
		image2 = cvCreateImage(cvGetSize(mapx), IPL_DEPTH_8U, 3);
	    cvRemap(image, image2, mapx, mapy);
 
	    //IplImage* clone = cvCloneImage(image);
	    //cvRemap(clone, image, mapx, mapy);
	    //cvReleaseImage(&clone);
	}

	char buffer[1024];
	sprintf(buffer,"%s/image%.3d.ppm",destdir,i);
	if(i%10 == 0){
	    printf(".");
	    fflush(stdout);
	}
	cvSaveImage(buffer, image2);

    }
    printf("\n");
}

int main() {
  return 0;
}
