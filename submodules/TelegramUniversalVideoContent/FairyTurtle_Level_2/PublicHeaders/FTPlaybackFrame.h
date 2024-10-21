//
//  FTPlaybackFrame.h
//  FTPlayerView
//
//  Created by Stan Potemkin on 16.10.2024.
//

#import <Foundation/Foundation.h>
@import CoreMedia;

NS_ASSUME_NONNULL_BEGIN

@interface FTPlaybackFrame : NSObject
@property(nonatomic, assign) BOOL isKeyframe;
@property(nonatomic, assign) BOOL shouldFlush;
@property(nonatomic, assign) CMSampleBufferRef sampleBuffer;
@property(nonatomic, assign) NSTimeInterval segmentEndtime;

- (instancetype)initWithSampleBuffer:(CMSampleBufferRef)sampleBuffer;
@end

NS_ASSUME_NONNULL_END
