//
//  FTAudioAacDecoder.h
//  FTPlayerView
//
//  Created by Stan Potemkin on 06.10.2024.
//

@import Foundation;
@import CoreMedia;
#import "../FTContainerUnpacker/FTContainerUnpacker.h"

NS_ASSUME_NONNULL_BEGIN

@protocol FTAudioDecoderDelegate;
@class FTContainerAudioMeta;
@class FTPlaybackFrame;

@interface FTAudioAacDecoder : NSObject
@property(nonatomic, weak) id<FTAudioDecoderDelegate> delegate;
- (instancetype)initWithMeta:(FTContainerAudioMeta *)meta;
- (void)feed:(NSData *)payload anchorTimestamp:(NSTimeInterval)anchorTimestamp batchId:(NSString *)batchId;
- (void)resetWithPosition:(NSUInteger)position;
@end

@protocol FTAudioDecoderDelegate
- (void)audioDecoder:(FTAudioAacDecoder *)decoder startBatchDecoding:(NSDate *)now batchId:(NSString *)batchId;
- (void)audioDecoder:(FTAudioAacDecoder *)decoder recognizeFrame:(FTPlaybackFrame *)frame batchId:(NSString *)batchId;
- (void)audioDecoder:(FTAudioAacDecoder *)decoder endBatchDecoding:(NSDate *)now batchId:(NSString *)batchId;
@end

NS_ASSUME_NONNULL_END
