#  MobileLighting System
## Overview
MobileLighting (ML) performs two general tasks:
* Dataset acquisition
* Processing pipeline

ML consists of 2 different applications:
* **MobileLighting Mac:** this is the control program with which the user interacts. It compiles to an executable and features a command-line interface.
* **MobileLighting iOS:** this is the iOS app that runs on the iPhone / iPod Touch. Its main task is taking photos (and videos, IMU data) upon request from the macOS control program. It manages the camera and also processes structured light images up through the decoding step.

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
    
