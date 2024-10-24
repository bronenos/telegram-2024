//
//  FTContainerFmp4Unpacker.h
//  FTPlayerView
//
//  Created by Stan Potemkin on 09.10.2024.
//

#import <Foundation/Foundation.h>
#import "FTContainerUnpacker.h"
#import "FTContainerVideoMeta.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTContainerFmp4Unpacker : FTContainerUnpacker
- (instancetype)initWithMeta:(FTContainerVideoMeta *)meta;
@end

NS_ASSUME_NONNULL_END
