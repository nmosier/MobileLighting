#  MobileLighting System
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
1. Clone the entire Xcode project from the GitHub repository, <https://github.com/nmosier/MobileLighting>.
1. Open the Xcode project at MobileLighting/MobileLighting.xcodeproj.
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
1. You may also encounter code signing errors — these can generally be resolved by opening the Xcode project's settings (in the left sidebar where all the files are listed, click on the blue Xcode project icon with the name <project>.xcodeproj). Select the target, and then open the "General" tab. Check the "Automatically manage signing" box under the "signing" section. [Here's a visual guide](readme_images/codesign.png)
1. Once MobileLighting Mac successfully compiles, click the "play" button in the top left corner to run it.
1. Compiling the MobileLighting_iPhone target should be a lot easier. Just select the MobileLighting_iPhone target from the same menu as before (in the top left corner). If you have an iPhone (or iPod Touch), connect it to the computer and then select the device in the menu. Otherwise, select "Generic Build-only Device". Then, hit ⌘+B to build for the device.
1. To upload the MobileLighting iOS app onto the device, click the "Play" button in the top left corner. This builds the app, uploads it to the phone, and runs it.
    
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
1. Structured lighting image capture
1. Ambient data capture
    1. Ambient images at multiple exposures
        1. Ambient
