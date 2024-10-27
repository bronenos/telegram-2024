//
//  FTVideoH264Decoder.m
//  FTPlayerView
//
//  Created by Stan Potemkin on 06.10.2024.
//

@import VideoToolbox;
#import "../FTContainerUnpacker/FTContainerVideoMeta.h"
#import "FTVideoH264Decoder.h"
#import "FTPlaybackFrame.h"
#import "../Extensions/NSData+.h"
#import "../ThirdParty/h264_sps_parse/h264_sps_parse.h"

static uint8_t const f_nalu_starting_pad = 0x00;
static uint8_t const f_nalu_short_header[] = {f_nalu_starting_pad, f_nalu_starting_pad, 0x01};
static uint8_t const f_nalu_short_header_len = 3;
static uint8_t const f_nalu_long_header[] = {f_nalu_starting_pad, f_nalu_starting_pad, f_nalu_starting_pad, 0x01};
static uint8_t const f_nalu_long_header_len = 4;
static uint8_t const f_nalu_diff_header_len = f_nalu_long_header_len - f_nalu_short_header_len;
static uint8_t const f_nalu_emulation_seq[] = {f_nalu_starting_pad, f_nalu_starting_pad, 0x03};
static uint8_t const f_nalu_emulation_seq_len = 3;

typedef enum {
    FTVideoH264_NALU_KIND_I_FRAME = 0x05,
    FTVideoH264_NALU_KIND_SPS_FRAME = 0x07,
    FTVideoH264_NALU_KIND_PPS_FRAME = 0x08,
    FTVideoH264_NALU_KIND_PB_FRAME = 0x01,
    FTVideoH264_NALU_KIND_FAILED_FRAME = 0x01,
} FTVideoH264_NALU_KIND;

@implementation FTVideoH264Decoder
{
    FTContainerVideoMeta *meta;
    
    NSLock *mutex;
    NSMutableData *contiguousBuffer;
    
    NSData *sequenceParams;
    NSData* pictureParams;
    
    CMFormatDescriptionRef format;
    BOOL shouldFlush;
    NSUInteger passedBytesNum;
    
    NSUInteger anchorTimestamp;
    NSUInteger anchorIndex;
    NSString *batchId;
}

- (instancetype)initWithMeta:(FTContainerVideoMeta *)meta {
    if ((self = [super init])) {
        self->meta = meta;
        
        mutex = [NSLock new];
        contiguousBuffer = [NSMutableData new];
        meta.fps = 30;
        
        [self recalculateActualFramerate];
    }
    
    return self;
}

- (void)feed:(NSData *)payload anchorTimestamp:(NSTimeInterval)anchorTimestamp batchId:(NSString *)batchId {
    printf("Decoding \n");
    
    if (payload.length == 0) {
        printf(" \n");
        return;
    }
    
    self->anchorTimestamp = anchorTimestamp;
    self->anchorIndex = 0;
    self->batchId = batchId;
    
    sequenceParams = sequenceParams ?: self->meta.sps;
    pictureParams = pictureParams ?: self->meta.pps;
    [self recalculateActualFramerate];
    
    // uint8_t *ptr = (uint8_t *) payload.bytes; 
    [contiguousBuffer appendData:payload];
    
    [self.delegate videoDecoder:self startBatchDecoding:[NSDate new] batchId:self->batchId];
    for (;;) {
        NSData *naluBuffer = [self findNextNaluWithHeader:self->meta];
        if (naluBuffer == NULL) {
            break;
        }
        else if (naluBuffer.length == 0) {
            continue;
        }
        else {
            [self processNalu:naluBuffer];
        }
    }
    
    [self.delegate videoDecoder:self endBatchDecoding:[NSDate new] batchId:self->batchId];
    
    printf(" \n");
}

- (void)resetWithPosition:(NSUInteger)position {
    [contiguousBuffer setData:[NSData new]]; 
    shouldFlush = true;
    passedBytesNum = position;
}

- (void)recalculateActualFramerate {
    h264_sps_info sps_info;
    h264_sps_parse(sequenceParams.bytes, (int)sequenceParams.length, &sps_info);
    
    if (sps_info.fps > 0 && sps_info.fps < NAN) {
        meta.fps = sps_info.fps;
    }
}

- (uint8_t *)searchStartCodeSince:(uint8_t *)read_ptr until:(const uint8_t *)over_ptr {
    while (read_ptr <= over_ptr - f_nalu_short_header_len) {
        if (0 == memcmp(read_ptr, f_nalu_short_header, f_nalu_short_header_len)) {
            return read_ptr;
        }
        else {
            read_ptr++;
        }
    }
    
    return NULL;
}

- (NSData *)findNextNaluWithHeader:(FTContainerVideoMeta *)header {
    if (header.naluLength > 0) {
        return [self findNextNalu_AVCC:header];
    }
    else {
        return [self findNextNalu_AnnexB];
    }
}

- (NSData *)findNextNalu_AVCC:(FTContainerVideoMeta *)header {
    if (contiguousBuffer.length == 0) {
        return NULL;
    }
    
    const NSRange dropRange = NSMakeRange(0, header.naluLength);
    
    uint32_t nalu_len = 0;
    switch (header.naluLength) {
        case 4:
            nalu_len = htonl(*(uint32_t *) contiguousBuffer.bytes);
            break;
        case 3:
            nalu_len = htonl(*(uint32_t *) contiguousBuffer.bytes) >> 8;
            break;
        case 2:
            nalu_len = htonl(*(uint16_t *) contiguousBuffer.bytes);
            break;
        case 1:
        case 0:
            nalu_len = htonl(*(uint8_t *) contiguousBuffer.bytes);
            break;
        default:
            return NULL;
    }
    
    /*const uint8_t zeroByte = *(uint8_t *) contiguousBuffer.bytes;
    if (zeroByte > 0x00) {
        [contiguousBuffer replaceBytesInRange:dropRange withBytes:&dropRange length:0];
        return [NSData new];
    }
    else if (nalu_len == 0) {
        [contiguousBuffer replaceBytesInRange:dropRange withBytes:&dropRange length:0];
        return [NSData new];
    }
    else*/ if (nalu_len >= contiguousBuffer.length) {
        return NULL;
    }
    
    const uint32_t len_placeholder = 4; 
    NSMutableData *output = [[NSMutableData alloc] initWithBytes:&len_placeholder length:len_placeholder];
    
    [contiguousBuffer replaceBytesInRange:dropRange withBytes:&dropRange length:0];
    
    const NSRange naluRange = NSMakeRange(0, nalu_len);
    [output appendData:[contiguousBuffer subdataWithRange:naluRange]];
    [contiguousBuffer replaceBytesInRange:naluRange withBytes:&naluRange length:0];
    
    return output;
}


- (NSData *)findNextNalu_AnnexB {
    uint8_t *read_ptr = (uint8_t *) contiguousBuffer.bytes;
    const uint8_t *over_ptr = read_ptr + contiguousBuffer.length;
    
    uint8_t *nalu_begin_ptr = [self searchStartCodeSince:read_ptr until:over_ptr];
    if (nalu_begin_ptr == NULL) {
        return NULL;
    }
    
    const uint8_t *nalu_over_ptr = [self searchStartCodeSince:(nalu_begin_ptr + f_nalu_short_header_len) until:over_ptr];
    if (nalu_over_ptr == NULL) {
        return NULL;
    }
    
    while (--nalu_over_ptr) {
        if (nalu_over_ptr <= read_ptr) {
            const NSRange dropRange = NSMakeRange(0, 1);
            [contiguousBuffer replaceBytesInRange:dropRange withBytes:&dropRange length:0];
            
            return NULL;
        }
        else if (*nalu_over_ptr) {
            const NSRange dropRange = NSMakeRange(nalu_begin_ptr - read_ptr, nalu_over_ptr - nalu_begin_ptr + 1);
            NSMutableData *naluBuffer = [NSMutableData dataWithBytes:&f_nalu_starting_pad length:1];
            [naluBuffer appendData:[contiguousBuffer subdataWithRange:dropRange]];
            [contiguousBuffer replaceBytesInRange:dropRange withBytes:&dropRange length:0];
            
            return naluBuffer;
        }
    }
    
    return NULL;
}

- (void)processNalu:(NSData *)naluBuffer {
    uint8_t *naluPtr = (uint8_t *) naluBuffer.bytes; 
    
    uint32_t *header = (uint32_t *) naluPtr;
    *header = htonl((uint32_t) (naluBuffer.length - f_nalu_long_header_len));
    
    const uint8_t header_suffix = naluPtr[f_nalu_long_header_len];
    const uint8_t kind = (header_suffix & 0x1F);
    const uint8_t has_failure = (header_suffix & 0x80);
    
    if (has_failure > 0) {
        return;
    }
    
    printf("Decoding kind: %hhu \n", kind);
    switch (kind) {
        case FTVideoH264_NALU_KIND_I_FRAME:
            [self ensureHavingDecoderForceUpdate:NO] && [self decodePixelBuffer:naluBuffer frameKind:kind];
            break;
        case FTVideoH264_NALU_KIND_SPS_FRAME:
            sequenceParams = [naluBuffer subdataFromIndex:f_nalu_long_header_len];
            [self recalculateActualFramerate];
            break;
        case FTVideoH264_NALU_KIND_PPS_FRAME:
            pictureParams = [naluBuffer subdataFromIndex:f_nalu_long_header_len];
            [self ensureHavingDecoderForceUpdate:YES];
            break;
        case FTVideoH264_NALU_KIND_PB_FRAME:
            [self ensureHavingDecoderForceUpdate:NO] && [self decodePixelBuffer:naluBuffer frameKind:kind];
            break;
        default:
            break;
    }
}

- (NSData *)removeEmulationSequences:(NSData *)input {
    NSMutableData *data = [input mutableCopy];
    
    static NSData *emulation_buffer;
    if (emulation_buffer == NULL) {
        emulation_buffer = [NSData dataWithBytes:f_nalu_emulation_seq length:f_nalu_emulation_seq_len];
    }
    
    NSRange searchingRange = NSMakeRange(0, data.length);
    for (;;) {
        const NSRange emulation_range = [data rangeOfData:emulation_buffer options:NSDataSearchBackwards range:searchingRange];
        if (emulation_range.location == NSNotFound) {
            return data;
        }
        else {
            [data replaceBytesInRange:emulation_range withBytes:f_nalu_emulation_seq length:f_nalu_emulation_seq_len - 1];
            searchingRange.length = emulation_range.location;
        }
    }
    
    return data;
}

- (BOOL)ensureHavingDecoderForceUpdate:(BOOL)forceUpdate {
    if (format && !forceUpdate) {
        return YES;
    }
    
    if (!(sequenceParams.length && pictureParams.length)) {
        return NO;
    }
    
    const uint8_t * const paramsPointers[2] = {
        sequenceParams.bytes,
        pictureParams.bytes,
    };
    
    const size_t lenPointers[2] = {
        sequenceParams.length,
        pictureParams.length,
    };
    
    OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(NULL, 2, paramsPointers, lenPointers, f_nalu_long_header_len, &format);
    if (status != noErr) {
        return NO;
    }
    
    return YES;
}

- (BOOL)decodePixelBuffer:(NSData *)data frameKind:(FTVideoH264_NALU_KIND)frameKind {
    CMBlockBufferRef blockBuffer = NULL;
    OSStatus status = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, NULL, data.length, kCFAllocatorDefault, NULL, 0, data.length, 0, &blockBuffer);
    if (status != kCMBlockBufferNoErr) {
        return NO;
    }
    
    status = CMBlockBufferReplaceDataBytes(data.bytes, blockBuffer, 0, data.length);
    if (status != kCMBlockBufferNoErr) {
        return NO;
    }
    
    CMSampleTimingInfo timingInfo;
    timingInfo.duration = CMTimeMake(1, meta.fps);
    timingInfo.decodeTimeStamp = kCMTimeInvalid;
    
    CMSampleBufferRef sampleBuffer = NULL;
    const size_t sampleLen = data.length;
    status = CMSampleBufferCreateReady(kCFAllocatorDefault, blockBuffer, format, 1, 1, &timingInfo, 1, &sampleLen, &sampleBuffer);
    if (status != kCMBlockBufferNoErr) {
        CFRelease(blockBuffer);
        return NO;
    }
    
    FTPlaybackFrame *frame = [[FTPlaybackFrame alloc] initWithSampleBuffer:sampleBuffer];
    frame.isKeyframe = (frameKind == FTVideoH264_NALU_KIND_I_FRAME);
    frame.shouldFlush = shouldFlush;
    frame.absoluteTimestamp = self->anchorTimestamp + ((NSTimeInterval) self->anchorIndex++) / ((NSTimeInterval) meta.fps);
    [self.delegate videoDecoder:self recognizeFrame:frame batchId:self->batchId];
    
    CFRelease(sampleBuffer);
    CFRelease(blockBuffer);
    
    shouldFlush = NO;
    
    return YES;
}
@end
