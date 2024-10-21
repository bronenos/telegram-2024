//
//  FTContainerUnpacker.m
//  FTPlayerView
//
//  Created by Stan Potemkin on 07.10.2024.
//

#import "FTContainerUnpacker.h"
#import "FTContainerFmp4Unpacker.h"
#import "FTContainerTsUnpacker.h"

@implementation FTContainerUnpacker
{
    NSArray *variants;
}

- (instancetype)initWithVariants:(NSArray *)variants {
    if ((self = [super init])) {
        self->variants = variants;
    }
    
    return self;
}

- (FTContainerUnpacker *)findResponsibleUnpacker:(NSData *)inputBuffer {
    for (FTContainerUnpacker *variant in variants) {
        FTContainerUnpacker *output = NULL;
        if ((output = [variant findResponsibleUnpacker:inputBuffer])) {
            return output;
        }
    }
    
    return NULL;
}

- (NSData *)extractPayload:(NSData *)inputBuffer {
    FTContainerUnpacker *unpacker = [self findResponsibleUnpacker:inputBuffer];
    return [unpacker extractPayload:inputBuffer];
}
@end
