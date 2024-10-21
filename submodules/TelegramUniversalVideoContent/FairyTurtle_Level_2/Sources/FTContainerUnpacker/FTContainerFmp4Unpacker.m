//
//  FTContainerFmp4Unpacker.m
//  FTPlayerView
//
//  Created by Stan Potemkin on 09.10.2024.
//

#import "FTContainerFmp4Unpacker.h"
#import "FTContainerMeta.h"
#import "../Extensions/NSData+.h"

static const size_t f_atom_header_len = 8; // len(4) + name(4)
static const uint32_t f_atom_len_entire = 0x00;
static const uint32_t f_atom_len_large = 0x01;
static const uint32_t f_atom_name_ftyp = 'pytf';
static const uint32_t f_atom_name_moov = 'voom';
static const uint32_t f_atom_name_moov_mhvd = 'dhhm';
static const uint32_t f_atom_name_trak = 'kart';
static const uint32_t f_atom_name_trak_edts = 'stde';
static const uint32_t f_atom_name_trak_mdia = 'aidm';
static const uint32_t f_atom_name_trak_mdia_mdhd = 'dhdm';
static const uint32_t f_atom_name_trak_mdia_hdlr = 'rldh';
static const uint32_t f_atom_name_trak_mdia_minf = 'fnim';
static const uint32_t f_atom_name_trak_mdia_minf_stbl = 'lbts';
static const uint32_t f_atom_name_trak_mdia_minf_stbl_stts = 'stts';
static const uint32_t f_atom_name_trak_mdia_minf_stbl_stsd = 'dsts';
static const uint32_t f_atom_name_trak_mdia_minf_stbl_stsd_avc1 = '1cva';
static const uint32_t f_atom_name_moof = 'foom';
static const uint32_t f_atom_name_moof_mfhd = 'dhfm';
static const uint32_t f_atom_name_moof_traf = 'fart';
static const uint32_t f_atom_name_mdat = 'tadm';
//static const uint32_t f_atom_name_dinf = 'fnid';
//static const uint32_t f_atom_name_stsd = 'dsts';
//static const uint32_t f_atom_name_avc1 = '1cva';
//static const uint32_t f_atom_name_avcC = 'Ccva';
//static const uint32_t f_atom_name_mp4a = 'a4pm';
//static const uint32_t f_atom_name_udta = 'atdu';
//static const uint32_t f_atom_name_meta = 'atem';
//static const uint32_t f_atom_name_ilst = 'tsli';


@implementation FTContainerFmp4Unpacker
{
    FTContainerMeta *meta;
}

- (instancetype)initWithMeta:(FTContainerMeta *)meta {
    if ((self = [super init])) {
        self->meta = meta;
    }
    
    return self;
}

- (FTContainerUnpacker *)findResponsibleUnpacker:(NSData *)inputBuffer {
    const uint32_t *input_ptr = inputBuffer.bytes;
    if (inputBuffer.length < f_atom_header_len) {
        return NULL;
    }
    
    const uint32_t atom_name = *(input_ptr + 1);
    switch (atom_name) {
        case f_atom_name_ftyp:
            return self;
        case f_atom_name_moof:
            return self;
        default:
            return NULL;
    }
}

- (NSData *)extractPayload:(NSData *)inputBuffer {
    printf("");
    printf("Parsing atoms \n");
    
    NSMutableData *output = [NSMutableData new];
    
    const char *bufferStart = inputBuffer.bytes;
    const char *bufferEnd = inputBuffer.bytes + inputBuffer.length;
    [self recursiveInspectBufferStart:bufferStart bufferOver:bufferEnd level:0 callback:^(uint32_t name, NSData *payload) {
        const void *payload_ptr = payload.bytes;
        switch (name) {
            case f_atom_name_moov_mhvd: {
                break;
            }
            case f_atom_name_moof: {
                break;
            }
            case f_atom_name_moof_mfhd: {
                break;
            }
            case f_atom_name_trak_mdia: {
                break;
            }
            case f_atom_name_trak_mdia_hdlr: {
                self->meta.mediaType = [[NSString alloc] initWithBytes:(payload_ptr + 8) length:4 encoding:NSASCIIStringEncoding];
                break;
            }
            case f_atom_name_trak_mdia_minf_stbl_stsd: {
                [self parseStsd:payload];
                break;
            }
            case f_atom_name_trak_mdia_minf_stbl_stsd_avc1: {
                break;
            }
            case f_atom_name_trak_mdia_minf_stbl_stts: {
                break;
            }
            case f_atom_name_trak_mdia_mdhd: {
                const uint8_t version = *((uint8_t*) (payload_ptr + 0));
                if (version == 0) {
                    self->meta.timeScale = htonl(*((uint32_t*) (payload_ptr + 12)));
                    self->meta.duration = htonl(*((uint32_t*) (payload_ptr + 16)));
                }
                else {
                    self->meta.timeScale = htonl(*((uint32_t*) (payload_ptr + 20)));
                    self->meta.duration = htonl(*((uint64_t*) (payload_ptr + 24)));
                }
                break;
            }
//            case f_atom_name_trak_mdia_minf_stbl_stss: {
//                const uint32_t num = htonl(*((uint32_t*) (payload_ptr + 4)));
//                for (uint32_t i = 0; i > num; i++) {
//                    [sync_samples addIndex:htonl(*((uint32_t*) (payload_ptr + 8 + i)))];
//                }
//                break;
//            }
            case f_atom_name_moof_traf: {
                break;
            }
            case f_atom_name_mdat: {
                [output appendData:payload];
                break;
            }
            default: {
                break;
            }
        }
    }];
    
    printf("");
    
    return output;
}

- (BOOL)recursiveInspectBufferStart:(const void *)startPtr bufferOver:(const void *)overPtr level:(int)level callback:(void(^)(uint32_t name, NSData *payload))callback {
#   define BUFFER_LEN() (overPtr - startPtr)
    
    if (BUFFER_LEN() < f_atom_header_len) {
        return NO;
    }
    
    while (BUFFER_LEN() >= f_atom_header_len) {
        const uint32_t * const atomPtr = startPtr;
        if (BUFFER_LEN() < f_atom_header_len) {
            startPtr += sizeof(uint32_t);
            return YES;
        }
        
        uint64_t payload_len = htonl(*atomPtr);
        startPtr += sizeof(uint32_t);
        
        if (payload_len == f_atom_len_entire) {
            payload_len = BUFFER_LEN() - f_atom_header_len;
        }
        else if (payload_len == f_atom_len_large) {
            startPtr += sizeof(uint32_t);
            return YES;
        }
        else {
            payload_len -= f_atom_header_len;
        }
        
        const uint32_t atom_name = *((uint32_t *) (startPtr));
        startPtr += sizeof(uint32_t);
        
        const uint8_t *n = (const void*) &atom_name;
        printf("|%d", level);
        for (int l = 0; l < level; l++) printf("-");
        printf("> atom[%c%c%c%c] len[%llu] \n", *(n + 0), *(n + 1), *(n + 2), *(n + 3), payload_len);
        
        switch (atom_name) {
            case f_atom_name_moov:
            case f_atom_name_trak:
            case f_atom_name_trak_edts:
            case f_atom_name_trak_mdia:
            case f_atom_name_trak_mdia_minf:
            case f_atom_name_trak_mdia_minf_stbl:
            case f_atom_name_moof:
            case f_atom_name_moof_traf:
                [self recursiveInspectBufferStart:(startPtr) bufferOver:(startPtr + payload_len) level:(level + 1) callback:callback];
                break;
            default:
                callback(atom_name, [NSData dataWithBytes:startPtr length:payload_len]);
                break;
        }
        
        startPtr += payload_len;
    }
    
#   undef BUFFER_LEN
    
    return YES;
}

- (void)parseStsd:(NSData *)input { 
    NSMutableData *buffer = [input mutableCopy];
    NSMutableDictionary *boxes = [NSMutableDictionary new];
    
    [buffer dropFirst:sizeof(uint32_t)];
    
    const uint32_t num = htonl(*((uint32_t *) (buffer.bytes)));
    [buffer dropFirst:sizeof(uint32_t)];
    
    for (uint32_t n = 0; n < num; n++) {
        uint32_t sublen = htonl(*((uint32_t *) (buffer.bytes)));
        [buffer dropFirst:sizeof(uint32_t)];
        sublen -= sizeof(uint32_t);
        
        self->meta.mediaCodec = [[NSString alloc] initWithBytes:buffer.bytes length:sizeof(uint32_t) encoding:NSASCIIStringEncoding];
        [buffer dropFirst:sizeof(uint32_t)];
        sublen -= sizeof(uint32_t);
        
        [buffer dropFirst:6];
        [buffer dropFirst:2];
        sublen -= 8;
        
        if ([self->meta.mediaCodec isEqualToString:@"avc1"]) {
            [buffer dropFirst:16];
            sublen -= 16;
            
            self->meta.pixelWidth = htonl(*((uint16_t *) (buffer.bytes)));
            [buffer dropFirst:sizeof(uint16_t)];
            sublen -= sizeof(uint16_t);

            self->meta.pixelHeight = htonl(*((uint16_t *) (buffer.bytes)));
            [buffer dropFirst:sizeof(uint16_t)];
            sublen -= sizeof(uint16_t);
            
            [buffer dropFirst:4];
            [buffer dropFirst:4];
            [buffer dropFirst:4];
            [buffer dropFirst:2]; // frames number
            [buffer dropFirst:32];
            [buffer dropFirst:2]; // depth
            [buffer dropFirst:2]; // reserved
            sublen -= 50;
            
            while (sublen > 0) {
                const uint32_t boxlen = htonl(*((uint32_t *) (buffer.bytes)));
                [buffer dropFirst:sizeof(uint32_t)];
                sublen -= sizeof(uint32_t);
                
                NSString *boxname = [[NSString alloc] initWithBytes:buffer.bytes length:sizeof(uint32_t) encoding:NSASCIIStringEncoding];
                [buffer dropFirst:sizeof(uint32_t)];
                sublen -= sizeof(uint32_t);
                
                const size_t boxparams_len = boxlen - sizeof(uint32_t) - sizeof(uint32_t);
                NSData *boxparams = [buffer dropFirst:boxparams_len];
                sublen -= boxparams_len;
                
                [boxes setObject:boxparams forKey:boxname];
            }
        }
        else {
            [buffer dropFirst:sublen];
        }
        
        NSData *avccBox = boxes[@"avcC"];
        if (avccBox) {
            const uint8_t *avccBoxPtr = avccBox.bytes;
            self->meta.naluLength = (*(avccBoxPtr + 4) & 0x03) + 1;
            
            const uint8_t *info = avccBoxPtr + 5;
            
            const uint8_t spsNum = *info++ & 0x31;
            for (uint8_t s = 0; s < spsNum; s++) {
                const uint16_t sps_len = htons(*(uint16_t *) info);
                info += sizeof(sps_len);
                
                self->meta.sps = self->meta.sps ?: [NSData dataWithBytes:info length:sps_len];
                info += sps_len;
            }
            
            const uint8_t ppsNum = *info++;
            for (uint8_t p = 0; p < ppsNum; p++) {
                const uint16_t pps_len = htons(*(uint16_t *) info);
                info += sizeof(pps_len);
                
                self->meta.pps = self->meta.pps ?: [NSData dataWithBytes:info length:pps_len];
                info += pps_len;
            }
        }
    }
}
@end
