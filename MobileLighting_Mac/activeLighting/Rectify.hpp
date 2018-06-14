
//
//  Header.h
//  ImgProcessor_Mac
//
//  Created by Nicholas Mosier on 6/13/18.
//  Copyright © 2018 Nicholas Mosier. All rights reserved.
//

#ifndef Header_h
#define Header_h
void rectify(int nimages, int camera, int w, int h, char* destdir, char** matrices, char** photos);
void rectifyDecoded(int nimages, int camera, char* destdir, char** matrices, char** photos);


#endif /* Header_h */
