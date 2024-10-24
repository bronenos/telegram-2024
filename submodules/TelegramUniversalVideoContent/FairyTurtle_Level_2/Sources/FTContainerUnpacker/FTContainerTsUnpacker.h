//
//  FTContainerTsUnpacker.h
//  FTPlayerView
//
//  Created by Stan Potemkin on 07.10.2024.
//

#import <Foundation/Foundation.h>
#import "FTContainerUnpacker.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTContainerTsUnpacker : FTContainerUnpacker
- (instancetype)initWithMeta:(FTContainerVideoMeta *)meta;
@end

NS_ASSUME_NONNULL_END
