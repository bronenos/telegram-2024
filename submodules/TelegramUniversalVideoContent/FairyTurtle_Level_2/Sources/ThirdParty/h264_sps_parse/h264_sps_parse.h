//
//  h264_sps_parse.h
//  FTPlayerView
//
//  Created by Stan Potemkin on 13.10.2024.
//

#ifndef h264_parse_sps_h
#define h264_parse_sps_h

// The code from:
// https://programmersought.com/article/82124104613/

typedef unsigned char BYTE;
typedef int INT;
typedef unsigned int UINT;

typedef struct
{
         const BYTE *data; //sps data
         UINT size; //sps data size
         UINT index; //The position mark of the current calculation position
} h264_sps_bit_stream;

typedef struct
{
    unsigned int profile_idc;
    unsigned int level_idc;
    
    unsigned int width;
    unsigned int height;
         unsigned int fps; //SPS may not contain FPS information
} h264_sps_info;

INT h264_sps_parse(const BYTE *data, UINT dataSize, h264_sps_info *info);

#endif /* h264_parse_sps_h */
