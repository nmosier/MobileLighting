#!/bin/bash
# shell script for making libraries required for image processing

pushd ./MobileLighting_Mac/activeLighting
make clean
make

pushd ./imageLib
make clean
make