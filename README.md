#  MobileLighting System
Nicholas Mosier, 07/2018
## Overview
MobileLighting (ML) performs two general tasks:
* Dataset acquisition
* Processing pipeline

ML consists of 2 different applications:
* **MobileLighting Mac:** this is the control program with which the user interacts. It compiles to an executable and features a command-line interface.
* **MobileLighting iOS:** this is the iOS app that runs on the iPhone / iPod Touch. Its main task is taking photos (and videos, IMU data) upon request from the macOS control program. It manages the camera and also processes structured light images up through the decoding step.

## MobileLighting Setup & Installation
### Compatibility
MobileLighting Mac is only compatible with macOS. Furthermore, Xcode must be installed on this Mac (it is a free download from the Mac App Store). This is partly because Xcode, the IDE used to develop, compile, and install MobileLighting, is only available on macOS. ML Control has only been tested on macOS High Sierra (10.13).

MobileLighting iOS is compatible with all devices that run iOS 11+ have a rear-facing camera and a flashlight.

### Installation
1. Install Xcode (available through the Mac App Store).
1. Install openCV 3. (Note: ML Mac only uses the openCV C++ API, so only these headers need to be linked properly.)
1. Install the Mac USB-to-Serial driver.
    1. Go to the website <https://www.mac-usb-serial.com/dashboard/>
    1. Download the package called **PL-2303 Driver (V3.1.5)**
    1. Login using these credentials:
    **username:** _nmosier_
    **password:** _scharsteinmobileimagematching_
    1. Open & install the driver package.
1. Clone the entire Xcode project from the GitHub repository, <https://github.com/nmosier/MobileLighting>:
`git clone https://github.com/nmosier/MobileLighting.git`
1. Run the script called `makeLibraries`
`cd MobileLighting`
`./makeLibraries`
1. Open the Xcode project at MobileLighting/MobileLighting.xcodeproj.
`open MobileLighting.xcodeproj`
1. Try building MobileLighting Control by opening the MobileLighting_Mac build target menu in the top-left corner of the window, to the right of the play button. Select "MobileLighting_Mac" -> "My Mac". Type ⌘+B (or "Product" -> "Build") to build MobileLighting_Mac. [See picture](readme_images/build_mac.png)
1. You'll probably encounter some errors at buildtime. These can normally be fixed by changing the Xcode settings and/or re-adding the linked frameworks & libraries. Here's a full list of libraries that should be linked with the Xcode project:
    * System libraries:
        * libopencv_calib3d
        * libopencv_core
        * libopencv_features2d
        * libopencv_imgproc
        * libopencv_videoio
        * libopencv_aruco
        * libopencv_imgcodecs
        * libpng
    * MobileLighting libraries/frameworks:
        * MobileLighting_Mac/CocoaAsyncSocket.framework
        * MobileLighting_iPhone/CocoaAsyncSocket.framework
        * MobileLighting_Mac/calib/libcalib (this currently needs to be manually recompiled using "make")
        * MobileLighting_Mac/activeLighting/libImgProcessor
        If they appear in _red_ in the left sidebar under "MobileLighting/Frameworks", then they cannot be found. This means they need to be re-added. Instructions:
        1. Select red libraries, hit "delete". A dialog pop up — click "Remove Reference".
        1. Now, re-add the libraries. Go back to the MobileLighting.xcodeproj settings, select the MobileLighting_Mac target, and go to the "General" tab and find the "Linked Libraries" section. Click the "+". [picture](readme_images/lib_readd.png)
        1. Some of the libraries will be in /usr/lib, and others will be in /usr/local/lib. To navigate to these folders in the dialog, click "Add Other..." and then the command ⌘+Shift+G. Enter in one of those paths, hit enter, and search for the libraries you need to re-add.
        1. After re-adding, the libraries should all have reappaeared under MobileLighting/Frameworks in the left sidebar, and there should no longer be any red ones.
1. You may also encounter code signing errors — these can generally be resolved by opening the Xcode project's settings (in the left sidebar where all the files are listed, click on the blue Xcode project icon with the name <project>.xcodeproj). Select the target, and then open the "General" tab. Check the "Automatically manage signing" box under the "signing" section. [Here's a visual guide](readme_images/codesign.png)
1. Once MobileLighting Mac successfully compiles, click the "play" button in the top left corner to run it.
1. Compiling the MobileLighting_iPhone target should be a lot easier. Just select the MobileLighting_iPhone target from the same menu as before (in the top left corner). If you have an iPhone (or iPod Touch), connect it to the computer and then select the device in the menu. Otherwise, select "Generic Build-only Device". Then, hit ⌘+B to build for the device.
1. To upload the MobileLighting iOS app onto the device, click the "Play" button in the top left corner. This builds the app, uploads it to the phone, and runs it.

## General Tips
Use the `help` command to list all possible commands. If you are unsure how to use the `help` command, type `help help`.

## Communication
The two apps of the  ML system communicate wirelessly using Bonjour / async sockets. ML Mac issues _CameraInstructions_ to ML iOS via _CameraInstructionPackets_, and ML iOS sends _PhotoDataPackets_ back to ML Mac.

**Tip**: when _not_ debugging ML iOS, I've found this setup to be the best: host a local WiFi network on the Mac and have the iPhone connect to that.

1. **Initialization:**
    * ML iOS publishes a _CameraService_ on the local domain (visibile over most Wifi, Bluetooth, etc.)
    * ML Mac publishes a _PhotoReceiver_ on the local domain (visibile over most Wifi, Bluetooth, etc.)
1. **Connection**
    * ML Mac searches for the iPhone's _CameraService_ using a _CameraServiceBrowser_
    * ML iOS searches for the Mac's _PhotoReceiver_ using a _PhotoSender_
    If and only if both services are found will communication between the Mac and iPhone be successful.
1. **Communication**
    * ML Mac always initiates communication with the iPhone by sending a _CameraInstructionPacket_, which necessarily contains a _CameraInstruction_ and optionally contains camera settings, such as exposure and focus.
    * For some _CameraInstructions_, ML iOS will send back data within a _PhotoData_ packet. Note that _not all data sent back to the Mac is photo data_: depending on the instruction to which it is responding, it may be a video, the current focus (as a lens position), or a structured light metadata file.
    * For some _CameraInstructions_, ML iOS will send back multiple _PhotoDataPackets_.
    * For some _CameraInstructions_, ML iOS will send back no _PhotoDataPackets_.
    * ML Mac will _always_ be expecting an exact number of _PhotoDataPackets_ for each _CameraInstruction_ it issues. For example, the _CameraInstruction.StartStructuredLighting_ sends back no packets, which the _CameraInstruction.StopVideoCapture_ sends back two packets.
1. **Caveats**
    * Something about the **MiddleburyCollege** WiFi network prevents ML Mac and ML iOS from discovering each other when connected. If ML iOS needs to be connected to MiddleburyCollege, then consider connecting the Mac and iPhone over Bluetooth.
    * In order to view **stdout** for ML iOS, it needs to be run through Xcode. When run through Xcode, the app is reinstalled before launch. Upon reinstallation, the iPhone needs an internet connection to verify the app. Therefore, when debugging ML iOS, it has worked best for me to connect the device to **MiddleburyCollege** and to the Mac over **Bluetooth**.
    * Connection over Bluetooth is at least _10x_ slower than connection over WiFi.
1. **Errors**
    * Sometimes, ML Mac and iOS have trouble finding each other's services. I'm not sure if this is due to poor WiFi/Bluetooth connection, or if it's a bug. In this case, try the following:
    * Make sure ML Mac and ML iOS are connected to the same WiFi network or connected 
    * Try restarting the ML Mac app / ML iOS app while keeping the other running.
    * Try restarting both apps, but launching ML iOS _before_ ML Mac.
    * Sometimes, the connection between ML Mac and ML iOS drops unexpectedly. The "solution" is to try the same steps listed directly above.


## Dataset Acquisition
There are numerous steps to dataset acquisition:
1. Calibration image capture
    1. Intrinsic calibration
    2. Multiview calibration
1. Structured lighting image capture
1. Ambient data capture
    1. Ambient images at multiple exposures
    1. Ambient video with IMU data
All these steps are executed/controlled at the MobileLighting Mac command-line interface.

The "waypoints" along the trajectory, all specified in the `trajectory.yml` file, are the positions at which all still images will be taken, including structured light, calibration, and ambient stills.

The focus remains fixed for the entire capture session. At the beginning of each session, ML Mac will send the `focus` parameter specified in the scene settings file.
(0.0 ≤ focus ≤ 1.0, where 0.0 is close and 1.0 is far) 

### Calibration
In order to capture calibration images, the Mac must be connected to the robot arm (and the iPhone).
#### Intrinsic Calibration
To capture intrinsics calibration images, use the following command:
`calibrate (-a|-d) [nPhotos]`
Flags:
* `-a`: append photos to existing ones in <scene>/orig/calibration/intrinsics
* `-d`: delete all photos in <scene>/orig/calibration/intrinsics before beginning capture
* (none): overwrite existing photos

ML Mac automatically sets the correct exposure before taking the photos. This exposure is specified in the `calibration -> exposureDuration, exposureISO` properties in the scene settings file.

ML Mac will ask you to hit enter as soon as you are ready to take the next photo. Each photo is saved at <scene>/orig/calibration/intrinsics with the filename IMG<#>.JPG.

### Stereo Calibration
To capture extrinsics calibration photos, use the following command:
`stereocalib (-a|-d) [nPhotos]`
Flags:
* `-a`: append photos to existing ones in <scene>/orig/calibration/stereo/pos*
* `-d`: delete all photos in <scene>/orig/calibration/stereo/pos* before beginning capture
* (none): overwrite existing photos

ML Mac automatically sets the correct exposure before taking the photos. This exposure is specified in the `calibration -> exposureDuration, exposureISO` properties in the scene settings file.

Before each photo, ML Mac will move the robot arm to the correct position and ask you to hit enter once it has reached the position. It then takes the photo, which is saved at <scene>/orig/calibration/stereo/posX, where X is the postion number.

### Structured Lighting
In order to capture structured lighting, the Mac must be connected to the robot arm, the switcher box via the display port and a USB-to-Serial cable, and the iPhone. Furthermore, all projectors being used must be connected to the output VGA ports of the switcher box.

Before capturing structured lighting, you must open a connection with the switcher box.
1. Find the name of the USB-to-Serial peripheral by opening the command line and entering
    `ls /dev/tty.*`
    Find the one that looks like it would be the USB-to-Serial device. For example, it may be `/dev/tty.RepleoXXXXX` (if you use the USB-to-Serial driver I use).
    Copy it to the clipboard.
1. Use the command
    `connect switcher [dev_path]`
    You can just paste what you've copied for `[dev_path]`.

Now, the projectors need to be configured. Make sure all projectors are connected to the switcher box and turnd on, and that the switcher box video input is connected to the Mac.
Note: if the switcher box video input is connected to the Mac's display port _after_ starting MobileLighting, then you will need to run the following ML Mac command:
`connect display`

Now, with all the projectors on and the switcher box connected and listening, the projectors need to be focused. First, turn on all projector displays with the command
`proj all on`
(type `help proj` for full usage)

To focus the projectors, it is useful to project a fine checkerboard pattern. Do this with
`cb [squareSize=4]`
Focus each projector such that the checkerboards projected onto the objects in the scene are crisp.

Now, you can begin taking structured lighting. The command is
`struclight [id] [projector #] [position #]`
Parameters:
* `id`: this specifies the projector position identifier. All code images will be saved in a folder according to this identifier, e.g. at `computed/decoded/unrectified/proj0/pos*`
* `projector #`: the projector number is the switcher box port to which the projector you want to use is connected. These numbers will be in the range 1–8.
* `position #`: the waypoint to take structured lighting from.

Before starting capture, ML Mac will move the arm to the position and ask you to hit "enter" once it reaches that position.
After that, capture begins. It projects first vertical, then horizontal binary code images. After each direction, the Mac should receive 2 files: a "metadata" file that simply contains the direction of the stripes and the decoded PFM file. It saves the PFM file to "computed/decoded/projX/posA". It then refines the decoded image.


### Ambient
In order to capture ambient data, the Mac must be connected to the robot arm (and the iPhone).

Multiple exposures can be used for ambient images. These are specified in the `ambient -> exposureDurations, exposureISOs` lists in the scene settings file.

#### Ambient Still Images
To capture ambient still images, use the following command:
`takeamb still (-f|-t)?`
Flags:
`-f`: use flash mode. This is the brightest illumination setting.
`-t`: use torch mode (i.e. turn on flashlight). This is dimmer than flash.
(none): take a normal ambient photo (with flash/torch off).

First, ML Mac moves the robot arm to the first position and then prompts the user to hit enter when in position.
Next, it takes still images with multiple exposures from all positions. It saves the photos to the directory orig/ambient/(normal | flash | torch).

#### Ambient Videos with IMU Data
Ambient videos are taken using the trajectory specified in `<scene>/settings/trajectory.yml`.
This YML file must contain a `trajectory` key. Under this key is a list of robot poses (either joints or coordinates in space, both 6D vectors).
Joint positoin: [joint1, joint2, joint3, joint4, joint5, joint6], all in radians
Coordinates: p[x, y, z, a, b, c], where a, b, c are Euler angles

ML Mac recreates the trajectory by generating a URScript script that it then sends to the robot. Additional parameters than can be tweaked in `trajectory.yml` are
* `timestep`: directly proportional to how long the robot takes to move between positions
* `blendRadius`: increases the smoothness of the trajectory.

To capture ambient videos, use the following command:
`takeamb video (-f|-t)? [exposure#=1]`
Flags:
* `-t`: take video with torch mode (flashlight) on.
* `-f`: same as `-t` (flash can only be enabled when taking a photo)
* (none): take a normal video (w/ flashlight off)
Parameters:
* `[exposure#=1]`: the exposure number is the index of the exposure in the list of exposures specified under  `ambient -> exposureDurations, exposureISOs`. If this parameter is not provided, it defaults to 1.

ML Mac first moves the robot arm to the first position and waits for the user to hit enter. Then, it sends the trajectory script to the robot and waits for the user to hit enter once the trajectory has been completed.

After the trajectory is completed, the iPhone sends the Mac two files:
* the video (a .mp4 file)
* the IMU data, saved as a Yaml list of IMU samples (a .yml file)
Both files are saved in `orig/ambient/video/(normal|torch)/exp#`.


## Image Processing
Here is the approximate outline of the image processing pipeline:
1. Compute intrinsics
1. Compute extrinsics for all stereo pairs
1. Rectify decoded images for all stereo pairs
1. Refine all rectified images (unrectified images should already have automatically been refined during data acquisition)
1. Disparity-match unrectified, rectified images
1. Merge disparity maps for unrectified, rectified
1. Reproject rectified, merged disparity maps
1. Merge reprojected disparities with original disparities and merged disparities for final result

### Intrinsics
To compute intrinsics, use the following command:
`getintrinsics [pattern=ARUCO_SINGLE]`
If no `pattern` is specified, then the default `ARUCO_SINGLE` is used.
The options for `pattern` are the following:
* CHESSBOARD
* ARUCO_SINGLE
The intrinsics file is saved at <scene>/computed/calibration/intrinsics.yml.

### Extrinsics
To compute extrinsics, use the following command:
`getextrinsics (-a | [left] [right])`

Parameters:
* `[left]`: left position
* `[right]`: right position
Flags:
* `-a`: compute extrinsics for all adjacent stereo pairs (pos0 & pos1, pos1 & pos2, etc.)
The extrinsics files are saved at <scene>/computed/calibration/extrinsics/extrinsicsAB.yml.

### Rectification
To rectify decoded images, use one of the following commands:
_for one position pair, one projector:_
`rectify [proj] [left] [right]`
where `[left]` and `[right]` are positions and `[proj]` is the projector position ID.

_for all projectors, one position pair_:
`rectify -a [left] [right]`
where `[left]` & `[right]` are positions

_for all projectors, all position pairs_:
`rectify -a -a`

### Refine
Use the `refine` command to refine decoded images. Like `rectify`, it can operate on one projector & one position (pair), all projectors & one position (pair), and all projectors & all position (pair)s, depending on the number of `-a` flags.

Additionally, the `-r` flag specifies that it should refine _rectified_ images. In this case, _two_ positions should be provided, constituting a stereo pair.
The absence of `-r` indicates _unrectified_ images should be refined. In this case, only _one_ position should be provided.

### Disparity
Use the `disparity` command to disparity-match refined, decoded images. The usage is
`disparity (-r) [proj] [left] [right]`
`disparity (-r) -a [left] [right]`
`disparity (-r) -a -a`
This saves the results in the directory `computed/disparity/(un)rectified/pos*`.

### Merge
Use the `merge` command to merge the disparity-matched imaged images. The usage is
`merge (-r) [left] [right]`
`merge (-r) -a`
The results are saved in the directory `computed/merged/(un)rectified/pos*`.

### Reproject
Use the `reproject` command to reproject the merged _rectified_ images from the previous step. Note that this step only operates on _rectified_ images. The usage is
`reproject [proj] [left] [right]`
`reproject -a [left] [right]`
`reproject -a -a`
The results are saved in the directory `computed/reprojected/pos*`.

### Merge (2)
Use the `merge2` command to merge the reprojected & disparity results for the rectified images. The usage is
`merge2 [left] [right]`
`merge2 -a`
The final results are saved in `computed/merged2/pos*`.


## Bridging C++ to Swift
Here's a link that describes the process: <http://www.swiftprogrammer.info/swift_call_cpp.html>
Some specific notes:
* all the bridging headers are already created/configured for MobileLighting (for both iOS and macOS targets)
* oftentimes, if a C++-only object is _not_ being passed in or out of a function (i.e. it appears in the function's signature), it can be directly compiled as a "C" function by adding `extern "C"` to the beginning of the function declaration. For example, `float example(int n)` would become `extern "C" float example(int n)`. You would then have to add `float example(int n);` to the bridging header. The function `example(Int32)` should then be accessible from Swift.
