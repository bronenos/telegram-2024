//
//  FTVideoH264Decoder.h
//  FTPlayerView
//
//  Created by Stan Potemkin on 06.10.2024.
//

@import Foundation;
@import CoreMedia;
#import "FTContainerUnpacker.h"

NS_ASSUME_NONNULL_BEGIN

@protocol FTVideoDecoderDelegate;
@class FTContainerVideoMeta;
@class FTPlaybackFrame;

@interface FTVideoH264Decoder : NSObject
@property(nonatomic, weak) id<FTVideoDecoderDelegate> delegate;
- (instancetype)initWithMeta:(FTContainerVideoMeta *)meta;
- (void)feed:(NSData *)payload anchorTimestamp:(NSTimeInterval)anchorTimestamp batchId:(NSString *)batchId;
- (void)resetWithPosition:(NSUInteger)position;
@end

@protocol FTVideoDecoderDelegate
- (void)videoDecoder:(FTVideoH264Decoder *)decoder startBatchDecoding:(NSDate *)now batchId:(NSString *)batchId;
- (void)videoDecoder:(FTVideoH264Decoder *)decoder recognizeFrame:(FTPlaybackFrame *)frame batchId:(NSString *)batchId;
- (void)videoDecoder:(FTVideoH264Decoder *)decoder endBatchDecoding:(NSDate *)now batchId:(NSString *)batchId;
@end

NS_ASSUME_NONNULL_END
