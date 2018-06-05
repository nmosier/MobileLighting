//
//  ImgProcessor.cpp
//  ImgProcessor
//
//  Created by Nicholas Mosier on 6/4/18.
//  Copyright © 2018 Nicholas Mosier. All rights reserved.
//

#include <iostream>
#include "ImgProcessor.hpp"
#include "ImgProcessorPriv.hpp"

void ImgProcessor::HelloWorld(const char * s)
{
    ImgProcessorPriv *theObj = new ImgProcessorPriv;
    theObj->HelloWorldPriv(s);
    delete theObj;
};

void ImgProcessorPriv::HelloWorldPriv(const char * s) 
{
    std::cout << s << std::endl;
};

