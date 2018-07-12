//
//  RobotControl.hpp
//  RobotControl
//
//  Created by Nicholas Mosier on 6/7/18.
//  Copyright © 2018 Nicholas Mosier. All rights reserved.
//



#ifndef RobotControl_
#define RobotControl_

/* The classes below are exported */
#pragma GCC visibility push(default)

int Client();
int Restore();
int Next();
int PowerdownRobot();
int MovePose(char *, float, float);
int MoveJoints(char *, float, float);
int MoveLinearX(float, float, float);
int MoveLinearY(float, float, float);
int MoveLinearZ(float, float, float);

#pragma GCC visibility pop
#endif
