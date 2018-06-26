//
//  MasterControl.h
//  RobotControl
//
//  Created by Nicholas Mosier on 6/7/18.
//  Copyright © 2018 Nicholas Mosier. All rights reserved.
//

int client();
int restore();
int next();
int powerdown();
int move_pose(std::string pose, float a = 0.3, float v = 0.3);
int move_joints(std::string pose, float a, float v);
int linear_x(float d, float a = 0.3, float v = 0.3);
int linear_y(float d, float a = 0.3, float v = 0.3);
int linear_z(float d, float a = 0.3, float v = 0.3);
