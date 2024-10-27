//
//  FTPlaybackFlight.swift
//  FTPlayerView
//
//  Created by Stan Potemkin on 06.10.2024.
//

import Foundation
import CoreVideo
import CoreMedia
import FairyTurtle_Level_2
import FairyTurtle_Level_3

protocol IFTPlaybackTimeline {
    var currentHeight: Int { get }
    var delegate: FTPlaybackFlightDelegate? { get set }
    func start(masterPlaylist: FTMasterPlaylist)
    func seekTo(timestamp ts: TimeInterval)
    func preloadMore(now: TimeInterval)
}

protocol FTPlaybackFlightDelegate: AnyObject {
    func playbackFlight(_ flight: IFTPlaybackTimeline, needPresentationRestart pts: Int64)
    func playbackFlight(_ flight: IFTPlaybackTimeline, haveNextVideoFrame frame: FTPlaybackFrame)
    func playbackFlight(_ flight: IFTPlaybackTimeline, haveNextAudioFrame frame: FTPlaybackFrame)
}

final class FTPlaybackFlight: IFTPlaybackTimeline, FTMediaProviderDelegate, FTVideoDecoderDelegate, FTAudioDecoderDelegate {
    private let contentDownloader: IFTContentDownloader
    private let mediaProvider: IFTMediaProvider
    
    weak var delegate: FTPlaybackFlightDelegate?
    
    private let queue = DispatchQueue(label: "ftplayback.queue.flight", qos: .userInteractive)
    private var videoMeta = FTContainerVideoMeta()
    private var audioMeta = FTContainerAudioMeta()
    private let containerUnpacker: FTContainerUnpacker
    private var videoDecoder: FTVideoH264Decoder
    private var audioDecoder: FTAudioAacDecoder
    
    private var masterPlaylist: FTMasterPlaylist?
    private var currentFrameIndex = Int64.zero
    private var preloadTimestamp = TimeInterval.zero
    private var decodingSegment: FTMediaPlaylistSegment?
    
    private var seekRequest: SeekRequest?
    private class SeekRequest {
        let requestId: String
        let timestamp: TimeInterval
        let percentage: Double
        var frames: [FTPlaybackFrame]
        
        init(timestamp: TimeInterval, percentage: Double) {
            self.requestId = UUID().uuidString
            self.timestamp = timestamp
            self.percentage = percentage
            self.frames = .ex_empty
        }
    }
    
    init(contentDownloader: FTContentDownloader) {
        self.contentDownloader = contentDownloader
        
        containerUnpacker = FTContainerUnpacker(variants: [
            FTContainerFmp4Unpacker(videoMeta: videoMeta, audioMeta: audioMeta),
            FTContainerTsUnpacker(videoMeta: videoMeta, audioMeta: audioMeta)
        ])
        
        videoDecoder = FTVideoH264Decoder(
            meta: videoMeta
        )
        
        audioDecoder = FTAudioAacDecoder(
            meta: audioMeta
        )
        
        mediaProvider = FTMediaProvider(
            warmDuration: 10,
            contentDownloader: contentDownloader
        )
        
        mediaProvider.delegate = self
        videoDecoder.delegate = self
        audioDecoder.delegate = self
    }
    
    var currentHeight: Int {
        return mediaProvider.currentHeight
    }
    
    func start(masterPlaylist: FTMasterPlaylist) {
        self.masterPlaylist = masterPlaylist
        
        currentFrameIndex = 0
        
        masterPlaylist.prefetchInfo { [weak self] info in
            if let self, let info {
                mediaProvider.bindPlaylist(info: info)
                preloadTimestamp = mediaProvider.preloadNext(current: 0, next: 0)
            }
        }
    }
    
    func activateStream(quality: Int) {
        guard let masterPlaylist else {
            return
        }
        
        let playlists = masterPlaylist.availableMediaPlaylists().sorted { $0.quality > $1.quality }
        
        if let playlist = playlists.first(where: { $0.quality <= quality }) {
            mediaProvider.bindPlaylist(info: playlist)
        }
        else if let playlist = playlists.last {
            mediaProvider.bindPlaylist(info: playlist)
        }
        else {
            print()
        }
    }
    
    func seekTo(timestamp ts: TimeInterval) {
        masterPlaylist?.prefetchInfo { [weak self] info in
            guard let self, let info else {
                return
            }
            
            let seekRequest = SeekRequest(
                timestamp: ts,
                percentage: info.segments.compactMap { segment in
                    let lower = segment.since
                    let upper = segment.until
                    
                    if lower <= ts, ts < upper {
                        return (ts - lower) / (upper - lower)
                    }
                    else {
                        return nil
                    }
                }.first ?? -1
            )
            self.seekRequest = seekRequest
            
            preloadTimestamp = mediaProvider.resetTo(timestamp: ts, batchId: seekRequest.requestId)
        }
    }
    
    func preloadMore(now: TimeInterval) {
        if seekRequest == nil {
            preloadTimestamp = mediaProvider.preloadNext(current: now, next: preloadTimestamp)
        }
    }
    
    private func commitVideoFrame(_ frame: FTPlaybackFrame, frameIndex: Int64?) -> Int64 {
        if currentFrameIndex == 0 {
            delegate?.playbackFlight(self, needPresentationRestart: 0)
        }
        
        defer {
            currentFrameIndex = frameIndex ?? currentFrameIndex + 1
        }
        
        let pts = CMTimeAdd(CMTime.zero, CMTimeMake(value: currentFrameIndex, timescale: videoMeta.fps))
        CMSampleBufferSetOutputPresentationTimeStamp(frame.sampleBuffer, newValue: pts)
        
        delegate?.playbackFlight(self, haveNextVideoFrame: frame)
        
        return currentFrameIndex
    }
    
    internal func mediaProvider(_ provider: any IFTMediaProvider, fresh: Bool, mappingData: Data?, segmentsData: [FTMediaPlaylistSegmentContent], batchId: String) {
        if fresh {
            currentFrameIndex = 0
            videoDecoder.reset(withPosition: 0)
            audioDecoder.reset(withPosition: 0)
        }
        
        if let mappingData {
            let payload = containerUnpacker.extractPayload(mappingData)
            if payload.count > 0 {
                videoDecoder.feed(payload as Data, anchorTimestamp: 0, batchId: batchId)
                audioDecoder.feed(payload as Data, anchorTimestamp: 0, batchId: batchId)
            }
        }
        
        for segmentData in segmentsData {
            if let req = seekRequest, !(segmentData.segment.since <= req.timestamp && req.timestamp < segmentData.segment.until) {
                continue
            }
            
            let payload = containerUnpacker.extractPayload(segmentData.data)
            if payload.count > 0 {
                decodingSegment = segmentData.segment
                videoDecoder.feed(payload as Data, anchorTimestamp: segmentData.segment.since, batchId: batchId)
                audioDecoder.feed(payload as Data, anchorTimestamp: segmentData.segment.since, batchId: batchId)
            }
        }
    }
    
    internal func videoDecoder(_ decoder: FTVideoH264Decoder, startBatchDecoding now: Date, batchId: String) {
    }
    
    internal func videoDecoder(_ decoder: FTVideoH264Decoder, recognizeFrame frame: FTPlaybackFrame, batchId: String) {
        if let decodingSegment {
            frame.segmentEndtime = decodingSegment.until
        }
        
        if let seekRequest, seekRequest.requestId == batchId {
            seekRequest.frames.append(frame)
        }
        else {
            _ = commitVideoFrame(frame, frameIndex: nil)
        }
    }
    
    internal func videoDecoder(_ decoder: FTVideoH264Decoder, endBatchDecoding now: Date, batchId: String) {
        if let seekRequest = seekRequest, seekRequest.requestId == batchId {
            defer {
                self.seekRequest = nil
            }
            
            let targetIndex = Int(Double(videoMeta.fps) * seekRequest.percentage)
//            var seekFrameIndex: Int64?
            
            var lowerIndex = targetIndex
            while (lowerIndex >= 0) {
                if lowerIndex >= seekRequest.frames.count {
                    continue
                }
                else if seekRequest.frames[lowerIndex].isKeyframe {
                    break
                }
                else {
                    lowerIndex -= 1
                }
            }
            
            var upperIndex = targetIndex
            while (upperIndex < seekRequest.frames.count) {
                if seekRequest.frames[upperIndex].isKeyframe {
                    break
                }
                else {
                    upperIndex += 1
                }
            }
            
            let keyIndex: Int
            if (targetIndex - lowerIndex) < (upperIndex - targetIndex) {
                keyIndex = max(0, lowerIndex)
            }
            else {
                keyIndex = min(seekRequest.frames.count - 1, upperIndex)
            }
            
            for (index, frame) in seekRequest.frames.dropFirst(keyIndex).enumerated() {
                if index == 0 {
                    _ = commitVideoFrame(frame, frameIndex: 0)
                }
                else {
                    _ = commitVideoFrame(frame, frameIndex: nil)
                }
            }
        }
    }
    
    internal func audioDecoder(_ decoder: FTAudioAacDecoder, startBatchDecoding now: Date, batchId: String) {
    }
    
    internal func audioDecoder(_ decoder: FTAudioAacDecoder, recognizeFrame frame: FTPlaybackFrame, batchId: String) {
    }
    
    internal func audioDecoder(_ decoder: FTAudioAacDecoder, endBatchDecoding now: Date, batchId: String) {
    }
}
