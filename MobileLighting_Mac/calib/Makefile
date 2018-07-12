SRC = calibration.cpp detection_check.cpp

BIN = calibrateWithSettings # cal camera_calibration readwrite imginfo \
	showimg showvideo smooth canny videoedges imdiff create_chessboard_obj image_creator create_board  create_new_chessboard create_3d_chessboard_obj calibration_aruco


# IMGLIB = /home/tmonaco/SummerProject/summer2018/opencvdemo/
ARCH := $(shell arch)
CALLIB = libcalib.$(ARCH).a

DBG= -g
CC = g++
WARN= -W -Wall 
CPPFLAGS = -O2 $(WARN) $(DBG) -I$(IMGLIB) -I/usr/include/opencv2 --std=c++17
LDLIBS = -lopencv_core -lopencv_highgui -lopencv_imgproc -lopencv_calib3d \
	-lopencv_features2d -lopencv_imgcodecs -lopencv_videoio -lopencv_aruco


OBJ = $(SRC:.cpp=.o)

# all: $(BIN)
all: $(CALLIB)
$(CALLIB): $(OBJ)
# $(CC) -o $@  $(OBJ) $(LDLIBS)
	rm -f $(CALLIB)
	ar ruc $(CALLIB) $(OBJ)
	ranlib $(CALLIB)
clean:
	rm -f $(BIN) *.o core*
