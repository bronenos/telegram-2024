//
//  FTPlaybackFrame.m
//  FTPlayerView
//
//  Created by Stan Potemkin on 16.10.2024.
//

#import "FTPlaybackFrame.h"

@implementation FTPlaybackFrame
- (instancetype)initWithSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    if ((self = [super init])) {
        self.sampleBuffer = sampleBuffer;
        
        CFRetain(sampleBuffer);
    }
    
    return self;
}

- (void)dealloc
{
    CFRelease(_sampleBuffer);
}
@end
