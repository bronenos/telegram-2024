//
//  FTContainerUnpacker.h
//  FTPlayerView
//
//  Created by Stan Potemkin on 07.10.2024.
//

@import Foundation;
#import "FTContainerVideoMeta.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTContainerUnpacker : NSObject
- (instancetype)initWithVariants:(NSArray *)variants;
- (FTContainerUnpacker *)findResponsibleUnpacker:(NSData *)inputBuffer;
- (NSData *)extractPayload:(NSData *)inputBuffer;
@end

NS_ASSUME_NONNULL_END
