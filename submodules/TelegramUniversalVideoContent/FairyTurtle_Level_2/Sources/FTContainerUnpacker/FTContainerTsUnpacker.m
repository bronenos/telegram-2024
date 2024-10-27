//
//  FTContainerTsUnpacker.m
//  FTPlayerView
//
//  Created by Stan Potemkin on 07.10.2024.
//

#import "FTContainerTsUnpacker.h"
#import "../Extensions/NSData+.h"

static const size_t f_proto_packet_len = 188;
static const size_t f_proto_header_len = 4;
static const uint8_t f_proto_sync_byte = 0x47;

@implementation FTContainerTsUnpacker
{
    FTContainerVideoMeta *videoMeta;
    FTContainerAudioMeta *audioMeta;
}

- (instancetype)initWithVideoMeta:(FTContainerVideoMeta *)videoMeta audioMeta:(FTContainerAudioMeta *)audioMeta {
    if ((self = [super init])) {
        self->videoMeta = videoMeta;
        self->audioMeta = audioMeta;
    }
    
    return self;
}

- (FTContainerUnpacker *)findResponsibleUnpacker:(NSData *)inputBuffer {
    if (inputBuffer.length == 0) {
        return NULL;
    }
    
    const uint8_t * const inputPtr = inputBuffer.bytes;
    if (*inputPtr == f_proto_sync_byte) {
        return self;
    }
    else {
        return NULL;
    }
}

- (NSData *)extractPayload:(NSData *)inputBuffer {
    NSMutableData *packetBuffer = [inputBuffer mutableCopy];
    NSMutableData *output = [NSMutableData new];
    
    while (packetBuffer.length >= f_proto_packet_len) {
        const uint8_t * const packetPtr = packetBuffer.bytes;
        if (*packetPtr != f_proto_sync_byte) {
            return output;
        }
        
        const uint8_t * const headerPtr = packetPtr;
        const BOOL hasAdaptation = ((headerPtr[3] & 0x20) > 0);
        const BOOL hasPayload = ((headerPtr[3] & 0x10) > 0);
        const BOOL hasPayloadOffset = ((headerPtr[1] & 0x40) > 0);
        
        if (hasPayload) {
            const uint8_t *payloadPtr = packetPtr;
            payloadPtr += f_proto_header_len;
            payloadPtr += (hasAdaptation ? 1 + *payloadPtr : 0);
            payloadPtr += (hasPayloadOffset ? 1 + *payloadPtr : 0);
            
            const size_t payloadOffset = payloadPtr - packetPtr;
            const NSRange payloadRange = NSMakeRange(payloadOffset, f_proto_packet_len - payloadOffset);
            NSData *payload = [packetBuffer subdataWithRange:payloadRange];
            [output appendData:payload];
        }
        
        const NSRange trimRange = NSMakeRange(0, f_proto_packet_len);
        [packetBuffer replaceBytesInRange:trimRange withBytes:&trimRange length:0];
    }
    
    return output;
}
@end
