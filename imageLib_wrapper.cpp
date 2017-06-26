//
//  imageLib_wrapper.cpp
//  demo
//
//  Created by Nicholas Mosier on 6/23/17.
//  Copyright © 2017 Nicholas Mosier. All rights reserved.
//

#include <stdio.h>
#include "imageLib.h"

extern "C" int getCShapeWidth() {
    CShape shape(100, 100, 100);
    return shape.width;
}


extern "C" void throwCError() {
    throw CError("Testing throwing C error");
}
