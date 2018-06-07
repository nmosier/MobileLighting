//
//  RobotControl.cpp
//  RobotControl
//
//  Created by Nicholas Mosier on 6/7/18.
//  Copyright © 2018 Nicholas Mosier. All rights reserved.
//

#include <iostream>
#include "RobotControl.hpp"

extern "C" int Client() {
    return client();
}
extern "C" int Server() {
    return server();
}
extern "C" int Restore() {
    return restore();
}
extern "C" int Next() {
    return next();
}
