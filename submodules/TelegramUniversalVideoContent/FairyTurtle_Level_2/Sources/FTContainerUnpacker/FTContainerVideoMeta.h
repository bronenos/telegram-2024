//
//  FTContainerVideoMeta.h
//  FTPlayerView
//
//  Created by Stan Potemkin on 14.10.2024.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTContainerVideoMeta : NSObject
@property(nonatomic, copy) NSString *mediaCodec;
@property(nonatomic, assign) size_t pixelWidth;
@property(nonatomic, assign) size_t pixelHeight;
@property(nonatomic, assign) uint32_t timeScale;
@property(nonatomic, assign) uint64_t duration;
@property(nonatomic, assign) uint8_t naluLength;
@property(nonatomic, copy) NSData *sps;
@property(nonatomic, copy) NSData *pps;
@property(nonatomic, assign) int32_t fps;
@property(nonatomic, retain) NSArray *videoChunkOffsets;
@property(nonatomic, retain) NSArray *videoSampleSizes;
@end

NS_ASSUME_NONNULL_END
