# Makefile for Active lighting code
# DS Sep 2013
# DS fixed 6/2017 to compile in MBH 632
# NM modified 7/2017 to compile as static library for use in MobileLighting

# SRC = Calibrate.cpp DetectForeground.cpp Disparities.cpp Decode.cpp \
 #     Threshold.cpp Main.cpp Rectify.cpp Reproject.cpp Utils.cpp

SRC = Disparities.cpp Decode.cpp Utils.cpp flowIO.cpp

BIN = ActiveLighting # FloVis

ARCH := $(shell arch)

# IMGLIB = /home/schar/summer2017/MiddStereo/imageLib
IMGLIB = "imageLib"

DBG = -g
CC = g++
WARN = -W -Wall
OPT ?= -O3
CPPFLAGS = $(OPT) $(WARN) $(DBG) -I$(IMGLIB) -I/usr/include/opencv
LDLIBS = -L$(IMGLIB) -lImg.$(ARCH)$(DBG) -lpng -lz
LDLIBS += -lopencv_core -lopencv_highgui -lopencv_imgproc -lopencv_calib3d -lopencv_features2d 


OBJ = $(SRC:.cpp=.o)

IMLIB = libImgProcessor.$(ARCH)$(DBG).a

#all: $(BIN)
all: $(IMLIB)

$(IMLIB): $(OBJ)
	rm -f $(IMLIB)
	ar ruc $(IMLIB) $(OBJ)
	ranlib $(IMLIB)

ActiveLighting: $(OBJ)
	$(CC) -o $@ $(OBJ) $(LDLIBS)
	#cp $@ $@-$(ARCH)

FloVis: FloVis.o Utils.o
	$(CC) -o $@ FloVis.o Utils.o $(LDLIBS)
	#cp $@ $@-$(ARCH)

clean: 
	#rm -f $(OBJ) FloVis.o core core.* *.stackdump
	rm -f $(OBJ) core* *.stackdump *.bak

#allclean: clean
#	rm -f $(BIN)
allclean: clean
	rm -f libImgProcessor*.a


depend:
	@makedepend -Y -- $(CPPFLAGS) -- $(SRC) 2>> /dev/null

# DO NOT DELETE THIS LINE -- make depend depends on it.
