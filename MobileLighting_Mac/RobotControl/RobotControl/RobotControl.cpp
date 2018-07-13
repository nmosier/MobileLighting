//
//  RobotControl.cpp
//  RobotControl
//
//  Created by Nicholas Mosier on 6/7/18.
//  Copyright © 2018 Nicholas Mosier. All rights reserved.
//

#include <iostream>
//#include "RobotControl.h"
#include "MovementControl.h"

extern "C" int Client() {
    return client();
}
extern "C" int Restore() {
    return restore();
}

extern "C" int Next() {
    return next();
}
extern "C" int PowerdownRobot() {
    return powerdown();
}
extern "C" int MovePose(char *pose, float a, float v) {
    if (a == 0 || v == 0) return move_pose(std::string(pose));
    else return move_pose(std::string(pose), a, v);
}
extern "C" int MoveJoints(char *pose, float a, float v) {
    return move_joints(std::string(pose), a, v);
}
extern "C" int MoveLinearX(float d, float a, float v) {
    if (a == 0 || v == 0) return linear_x(d);
    else return linear_x(d, a, v);
}
extern "C" int MoveLinearY(float d, float a, float v) {
    if (a == 0 || v == 0) return linear_y(d);
    else return linear_y(d, a, v);
}
extern "C" int MoveLinearZ(float d, float a, float v) {
    if (a == 0 || v == 0) return linear_z(d);
    else return linear_z(d, a, v);
}
