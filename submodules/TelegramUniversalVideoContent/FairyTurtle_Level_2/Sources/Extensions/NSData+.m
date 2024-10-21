//
//  fd.m
//  FTPlayerView
//
//  Created by Stan Potemkin on 07.10.2024.
//

#import "NSData+.h"

@implementation NSData (Custom)
- (NSData *)subdataFromIndex:(NSUInteger)index {
    const NSRange range = NSMakeRange(index, self.length - index);
    return [self subdataWithRange:range];
}
@end

@implementation NSMutableData (Custom)
- (NSData *)dropFirst:(NSUInteger)index {
    const NSRange range = NSMakeRange(0, index);
    NSData *subdata = [self subdataWithRange:range];
    
    [self replaceBytesInRange:range withBytes:&index length:0];
    return subdata;
}
@end
