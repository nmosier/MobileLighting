// Created by Nicholas Mosier, 06/2018

float maxgrad0 = 1.0; // expected maximum gradient of code values per pixel in code direction
float maxgrad1 = 0.1; // expected maximum gradient of code values per pixel in perpendicular direction

enum refine_mode_t {
    refine_old,
    refine_angle,
    refine_planar
};

refine_mode_t refine_mode = refine_old;

int refine_plane_windowsize = 5;	// # of pixels for width & height of window considered
int refine_plane_minsupport = 20;
float refine_plane_maxdiff = 2.0;
