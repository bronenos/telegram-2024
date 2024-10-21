//
//  fd.h
//  FTPlayerView
//
//  Created by Stan Potemkin on 07.10.2024.
//

@import Foundation;
@import UIKit;

NS_ASSUME_NONNULL_BEGIN

@interface NSData (Custom)
- (NSData *)subdataFromIndex:(NSUInteger)index;
@end

@interface NSMutableData (Custom)
- (NSData *)dropFirst:(NSUInteger)index;
@end

NS_ASSUME_NONNULL_END
