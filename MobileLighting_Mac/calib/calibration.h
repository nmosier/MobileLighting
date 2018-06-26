#ifndef _calibration_H
#define _calibration_H
#endif

#include "opencv2/core/core.hpp"
#include "opencv2/imgproc/imgproc.hpp"
#include "opencv2/calib3d/calib3d.hpp"
#include "opencv2/highgui/highgui.hpp"

#include <iostream>
#include <fstream>
#include <sstream>
#include <cctype>
#include <stdio.h>
#include <string>
#include <time.h>
//#include "aruco.h"

using namespace std;
using namespace cv;
//using namespace aruco;

int calibrateWithSettings( const string inputSettingsFile );


struct intrinsicCalibration {
    Mat cameraMatrix, distCoeffs;   //intrinsic matrices
    vector<Mat> rvecs, tvecs;       //extrinsic rotation and translation vectors
    vector<vector<Point2f> > imagePoints;   //corner points on 2d image
    vector<vector<Point3f> > objectPoints;  //corresponding 3d object points
    vector<float> reprojErrs;   //vector of reprojection errors for each pixel
    double totalAvgErr;     //average error across every pixel
};

struct stereoCalibration {
    Mat R, T, E, F;         //Extrinsic matrices (rotation, translation, essential, fundamental)
    Mat R1, R2, P1, P2, Q;  //Rectification parameters ()
    Rect validRoi[2];       //Rectangle within the rectified image that contains all valid points
};


class Settings {
public:
    Settings();

    enum Pattern { CHESSBOARD, ARUCO_SINGLE, ARUCO_BOX, NOT_EXISTING };
    enum Mode { INTRINSIC, STEREO, PREVIEW, INVALID };

    void write(FileStorage& fs) const;
    void read(const FileNode& node);
    void interprate();
    cv::Mat imageSetup(int imageIndex);

    static bool readStringList(const string& filename, vector<string>& l);
    //static bool readConfigList( const string& filename, vector<MarkerMap>& l );
    static bool readIntrinsicInput( const string& filename, intrinsicCalibration& intrinsicInput );
    static bool fileCheck( const string& filename, FileStorage fs, const char * var);
    void saveIntrinsics(intrinsicCalibration &inCal);
    void saveExtrinsics(stereoCalibration &sterCal);


    // Properties
    Mode mode;
    Pattern calibrationPattern;   // One of the Chessboard, circles, or asymmetric circle pattern

    // Chessboard settings
    Size boardSize;                 // The size of the board -> Number of items by width and height
    float squareSize;               // The size of a square in your defined unit (point, millimeter,etc).

    // Input settings
    vector<string> imageList;
    string imageListFilename;

    //vector <MarkerMap> configList; // Aruco config files
    //string configListFilename;    // Input filename for aruco config files

    intrinsicCalibration intrinsicInput; // Struct to store inputted intrinsics
    string intrinsicInputFilename;    // Leave it at 0 to calculate new intrinsics
    bool useIntrinsicInput;

    // Output settings
    string intrinsicOutput;    // File to write results of intrinsic calibration
    string extrinsicOutput;    // File to write extrisics of stereo calibration

    string undistortedPath;    // Path at which to save undistorted images (leave 0 to not save undistorted)
    string rectifiedPath;      // Path at which to save rectified images (leave 0 to not save rectified)

    // Itrinsic calibration settings
    string fixDistCoeffs;              // A sequence of five digits (0 or 1) that control which distortion coefficients will be fixed
    float aspectRatio;              // The aspect ratio. If it is inputted as 1, it will be fixed in calibration
    bool assumeZeroTangentDist;     // Assume zero tangential distortion
    bool fixPrincipalPoint;         // Fix the principal point at the center
    int flag;                       // Flag to modify calibration

    // UI settings
    bool showUndistorted;           // Show undistorted images after intrinsic calibration
    bool showRectified;           // Show rectified images after stereo calibration
    bool showArucoCoords;           // If false, IDs will be printed instead

    // Program variables
    int nImages;
    Size imageSize;
    int nConfigs;

    // Live preview settings
    int cameraID;
    VideoCapture capture;

    bool goodInput;

private:
    string modeInput;
    string patternInput;
    string cameraIDInput;
};

// static void read(const FileNode& node, Settings& x, const Settings& default_value = Settings());
// static void write(FileStorage& fs, const string&, const Settings& x);
