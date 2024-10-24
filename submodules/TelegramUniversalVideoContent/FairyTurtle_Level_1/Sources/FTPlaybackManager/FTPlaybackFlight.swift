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
    var delegate: FTPlaybackFlightDelegate? { get set }
    func start(masterPlaylist: FTMasterPlaylist)
    func seekTo(timestamp ts: TimeInterval)
    func preloadMore(now: TimeInterval)
}

protocol FTPlaybackFlightDelegate: AnyObject {
    func playbackFlight(_ flight: IFTPlaybackTimeline, needPresentationRestart pts: Int64)
    func playbackFlight(_ flight: IFTPlaybackTimeline, haveNextFrame frame: FTPlaybackFrame)
}

final class FTPlaybackFlight: IFTPlaybackTimeline, FTMediaProviderDelegate, FTVideoDecoderDelegate {
    private let contentDownloader: IFTContentDownloader
    private let mediaProvider: IFTMediaProvider
    
    weak var delegate: FTPlaybackFlightDelegate?
    
    private let queue = DispatchQueue(label: "ftplayback.queue.flight", qos: .userInteractive)
    private var meta = FTContainerVideoMeta()
    private let unpacker: FTContainerUnpacker
    private var decoder: FTVideoH264Decoder
    
    private var masterPlaylist: FTMasterPlaylist?
    private var currentFrameIndex = Int64.zero
    private var preloadTimestamp = TimeInterval.zero
    private var decodingSegment: FTMediaPlaylistSegment?
    
    private var seekRequest: SeekRequest?
    private class SeekRequest {
        let timestamp: TimeInterval
        let percentage: Double
        var frames: [FTPlaybackFrame]
        
        init(timestamp: TimeInterval, percentage: Double) {
            self.timestamp = timestamp
            self.percentage = percentage
            self.frames = .ex_empty
        }
    }
    
    init(contentDownloader: FTContentDownloader) {
        self.contentDownloader = contentDownloader
        
        unpacker = FTContainerUnpacker(variants: [
            FTContainerFmp4Unpacker(meta: meta),
            FTContainerTsUnpacker(meta: meta)
        ])
        
        decoder = FTVideoH264Decoder(meta: meta)
        
        mediaProvider = FTMediaProvider(
            warmDuration: 10,
            contentDownloader: contentDownloader
        )
        
        mediaProvider.delegate = self
        decoder.delegate = self
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
        
        let playlists = masterPlaylist.availableMediaPlaylists()
        
        if let playlist = playlists.first(where: { $0.quality == quality }) {
            mediaProvider.bindPlaylist(info: playlist)
        }
        else if let playlist = playlists.first {
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
            
            seekRequest = SeekRequest(
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
            
            preloadTimestamp = mediaProvider.resetTo(timestamp: ts)
        }
    }
    
    func preloadMore(now: TimeInterval) {
        if seekRequest == nil {
            preloadTimestamp = mediaProvider.preloadNext(current: now, next: preloadTimestamp)
        }
    }
    
    private func commitFrame(_ frame: FTPlaybackFrame, frameIndex: Int64?) -> Int64 {
        if currentFrameIndex == 0 {
            delegate?.playbackFlight(self, needPresentationRestart: 0)
        }
        
        defer {
            currentFrameIndex = frameIndex ?? currentFrameIndex + 1
        }
        
        print("flow: flight: set pts \(Double(currentFrameIndex) / Double(meta.fps)) per \(meta.fps)")
        let pts = CMTimeAdd(CMTime.zero, CMTimeMake(value: currentFrameIndex, timescale: meta.fps))
        CMSampleBufferSetOutputPresentationTimeStamp(frame.sampleBuffer, newValue: pts)
        
        delegate?.playbackFlight(self, haveNextFrame: frame)
        
        return currentFrameIndex
    }
    
    internal func mediaProvider(_ provider: any IFTMediaProvider, fresh: Bool, mappingData: Data?, segmentsData: [FTMediaPlaylistSegmentContent]) {
        if fresh {
            currentFrameIndex = 0
//            decoder.reset()
        }
        
        if let mappingData {
            let payload = unpacker.extractPayload(mappingData)
            if payload.count > 0 {
                decoder.feed(payload as Data)
            }
        }
        
        for segmentData in segmentsData {
            if let req = seekRequest, !(segmentData.segment.since <= req.timestamp && req.timestamp < segmentData.segment.until) {
                continue
            }
            
            let payload = unpacker.extractPayload(segmentData.data)
            if payload.count > 0 {
                print("flow: flight: feed to decoder")
                decodingSegment = segmentData.segment
                decoder.feed(payload as Data)
            }
        }
    }
    
    internal func videoDecoder(_ decoder: FTVideoH264Decoder, startBatchDecoding now: Date) {
    }
    
    internal func videoDecoder(_ decoder: FTVideoH264Decoder, recognizeFrame frame: FTPlaybackFrame) {
        if let decodingSegment {
            frame.segmentEndtime = decodingSegment.until
        }
        
        if let seekRequest {
            seekRequest.frames.append(frame)
        }
        else {
            print("flow: flight: commit the frame")
            _ = commitFrame(frame, frameIndex: nil)
        }
    }
    
    internal func videoDecoder(_ decoder: FTVideoH264Decoder, endBatchDecoding now: Date) {
        if let seekRequest = seekRequest {
            defer {
                self.seekRequest = nil
            }
            
            let targetIndex = Int(Double(meta.fps) * seekRequest.percentage)
//            var seekFrameIndex: Int64?
            
            var lowerIndex = targetIndex
            while (lowerIndex >= 0) {
                if seekRequest.frames[lowerIndex].isKeyframe {
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
                    _ = commitFrame(frame, frameIndex: 0)
                }
                else {
                    _ = commitFrame(frame, frameIndex: nil)
                }
            }
        }
    }
}
