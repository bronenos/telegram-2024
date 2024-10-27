//
//  FTAudioAacDecoder.m
//  FTPlayerView
//
//  Created by Stan Potemkin on 06.10.2024.
//

@import VideoToolbox;
#import "../FTContainerUnpacker/FTContainerVideoMeta.h"
#import "../FTContainerUnpacker/FTContainerAudioMeta.h"
#import "FTAudioAacDecoder.h"
#import "FTPlaybackFrame.h"
#import "../Extensions/NSData+.h"
#import "../ThirdParty/h264_sps_parse/h264_sps_parse.h"

@implementation FTAudioAacDecoder
{
    FTContainerAudioMeta *meta;
    
    NSLock *mutex;
    NSMutableData *contiguousBuffer;
    
    AudioStreamBasicDescription asbd;
    BOOL shouldFlush;
    NSUInteger passedBytesNum;
    
    NSUInteger anchorTimestamp;
    NSUInteger anchorIndex;
    NSString *batchId;
}

- (instancetype)initWithMeta:(FTContainerAudioMeta *)meta {
    if ((self = [super init])) {
        self->meta = meta;
        
        mutex = [NSLock new];
        contiguousBuffer = [NSMutableData new];
    }
    
    return self;
}

- (void)feed:(NSData *)payload anchorTimestamp:(NSTimeInterval)anchorTimestamp batchId:(NSString *)batchId {
    if (payload.length == 0) {
        return;
    }
    
//    asbd.mSampleRate = 0; // fill from meta
//    asbd.mFormatID = 0; // fill from meta
//    asbd.mFormatFlags = 0; // fill from meta
//    asbd.mBytesPerPacket = 0; // fill from meta
//    asbd.mFramesPerPacket = 0; // fill from meta
//    asbd.mBytesPerFrame = 0; // fill from meta
//    asbd.mChannelsPerFrame = 0; // fill from meta
//    asbd.mBitsPerChannel = 0; // fill from meta
//    asbd.mReserved = 0; // fill from meta
    
    self->anchorTimestamp = anchorTimestamp;
    self->anchorIndex = 0;
    self->batchId = batchId;
    
    // uint8_t *ptr = (uint8_t *) payload.bytes; 
    [contiguousBuffer appendData:payload];
    
    [self.delegate audioDecoder:self startBatchDecoding:[NSDate new] batchId:self->batchId];
//    for (;;) {
//    }
    [self.delegate audioDecoder:self endBatchDecoding:[NSDate new] batchId:self->batchId];
    
    printf(" \n");
}

- (void)resetWithPosition:(NSUInteger)position {
    [contiguousBuffer setData:[NSData new]]; 
    shouldFlush = true;
    passedBytesNum = position;
}
@end
