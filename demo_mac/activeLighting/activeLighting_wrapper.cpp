//
//  activeLighting_wrapper.cpp
//  demo
//
//  Created by Nicholas Mosier on 6/28/17.
//  Copyright © 2017 Nicholas Mosier. All rights reserved.
//

#include <stdio.h>
#include "ImgProcessor.h"

extern "C" void refineDecodedIm(char *outdir, int direction, char* decodedIm) {
    refine(outdir, direction, decodedIm);	// returns final CFloatImage, ignore
}

extern "C" void test_wrapped(void) {
    test();
}
