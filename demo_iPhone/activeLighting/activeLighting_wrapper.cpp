//
//  activeLighting_wrapper.cpp
//  demo
//
//  Created by Nicholas Mosier on 6/26/17.
//  Copyright © 2017 Nicholas Mosier. All rights reserved.
//

#include <stdio.h>
#include "ActiveLighting.h"

extern "C" int activeLighting(int argc, char *argv[]) {
    return main(argc, argv);
}

