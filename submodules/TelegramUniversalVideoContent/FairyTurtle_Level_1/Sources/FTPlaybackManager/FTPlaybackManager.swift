//
//  FTPlaybackManager.swift
//  FTPlayerView
//
//  Created by Stan Potemkin on 06.10.2024.
//

import Foundation
import CoreMedia
import AVFoundation
import FairyTurtle_Level_2
import FairyTurtle_Level_3

protocol IFTPlaybackManager: AnyObject {
//    var delegate: FTPlaybackManagerDelegate? { get set }
    func bind(videoLayer: AVSampleBufferDisplayLayer)
    func play(remoteUrl: URL)
    func availableQualities() -> [Int]
    func setQuality(_ value: Int?)
    func setSpeed(_ value: Double)
    func startTesting()
}

//protocol FTPlaybackManagerDelegate: AnyObject {
//    func playbackManager(_ manager: IFTPlaybackManager, timeBase: CMTimebase)
//}

public final class FTPlaybackManager: IFTPlaybackManager, FTPlaybackFlightDelegate {
//    weak var delegate: FTPlaybackManagerDelegate?
    
    private let contentDownloader: FTContentDownloader
    private let playbackFlight: FTPlaybackFlight
    
    private var videoLayer: AVSampleBufferDisplayLayer?
    private var displayLink: CADisplayLink?
    
    private var masterPlaylist: FTMasterPlaylist?
    private let framesOperationQueue = DispatchQueue.global(qos: .userInteractive)
    private let framesMutex = NSLock()
    private var framesDeque = [FTPlaybackFrame]() // replace with Dequeue<FTPlaybackFrame>
    private var nextPreloadTime = TimeInterval.zero
    
    public init() {
        contentDownloader = FTContentDownloader(
            urlSession: .shared,
            fileManager: .default
        )
        
        playbackFlight = FTPlaybackFlight(
            contentDownloader: contentDownloader
        )
        
        playbackFlight.delegate = self
    }
    
    public func bind(videoLayer: AVSampleBufferDisplayLayer) {
        self.videoLayer = videoLayer
    }
    
    public func play(remoteUrl: URL) {
        let masterPlaylist = FTMasterPlaylist(
            remoteUrl: remoteUrl,
            supportedCodecs: ["avc1", "mp4a"], // by tech task: "fmp4 / H264 / AAC"
            contentDownloader: contentDownloader
        )
        self.masterPlaylist = masterPlaylist
        
        playbackFlight.start(masterPlaylist: masterPlaylist)
        
        displayLink = CADisplayLink(target: self, selector: #selector(handleFrameTick))
        if let displayLink {
            displayLink.preferredFramesPerSecond = 5
            displayLink.add(to: .main, forMode: .common)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(30)) { [weak self] in
//            self?.playbackFlight.seekTo(timestamp: 8)
//            self?.setSpeed(2.0)
            self?.setQuality(432)
        }
    }
    
    public func availableQualities() -> [Int] {
        if let playlists = masterPlaylist?.availableMediaPlaylists() {
            return playlists.map(\.quality)
        }
        else {
            return .ex_empty
        }
    }
    
    public func setQuality(_ value: Int?) {
        if let value {
            playbackFlight.activateStream(quality: value)
        }
        else {
            playbackFlight.activateStream(quality: 0)
        }
    }
    
    public func setSpeed(_ value: Double) {
        if let controlTimebase = videoLayer?.controlTimebase {
            CMTimebaseSetRate(controlTimebase, rate: value)
        }
    }
    
    public func startTesting() {
        if let url = URL(string: TestingPlaylistUrl.primary.rawValue) {
            play(remoteUrl: url)
        }
    }
    
    @objc private func handleFrameTick() {
        playbackFlight.preloadMore(now: nextPreloadTime)
        
        framesMutex.lock()
        if framesDeque.hasElements {
            framesOperationQueue.async { [weak self] in
                self?.handleFrameTick_enqueueBuffers()
            }
        }
        framesMutex.unlock()
    }
    
    private func handleFrameTick_enqueueBuffers() {
        guard let videoLayer else {
            return
        }
        
        framesMutex.lock()
        defer {
            framesMutex.unlock()
        }
        
        while framesDeque.hasElements {
            if videoLayer.isReadyForMoreMediaData {
                let frame = framesDeque.removeFirst()
                videoLayer.enqueue(frame.sampleBuffer)
                nextPreloadTime = frame.segmentEndtime
            }
            else {
                break
            }
        }
    }
    
    internal func playbackFlight(_ flight: any IFTPlaybackTimeline, needPresentationRestart pts: Int64) {
        guard let videoLayer else {
            return
        }
        
        videoLayer.flush()
        
        var controlTimebase: CMTimebase?
        CMTimebaseCreateWithSourceClock(allocator: nil, sourceClock: CMClockGetHostTimeClock(), timebaseOut: &controlTimebase)
        
        if let controlTimebase {
            videoLayer.controlTimebase = controlTimebase
            CMTimebaseSetTime(controlTimebase, time: CMTime.zero)
            CMTimebaseSetRate(controlTimebase, rate: 1.0)
        }
    }
    
    internal func playbackFlight(_ flight: any IFTPlaybackTimeline, haveNextFrame frame: FTPlaybackFrame) {
        framesMutex.lock()
        defer {
            framesMutex.unlock()
        }
        
        if frame.shouldFlush {
            framesDeque.removeAll()
        }
        
        framesDeque.append(frame)
    }
}

fileprivate enum TestingPlaylistUrl: String {
    static let primary = bipBop_master_fmp4_byterange
    case bipBop_master_fmp4_byterange = "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8"
    case bigBuckBunny_media_ts_timerange = "https://test-streams.mux.dev/x36xhzz/url_6/193039199_mp4_h264_aac_hq_7.m3u8"
    case homeMaster_h264_adts = "https://flipfit-cdn.akamaized.net/flip_hls/663d1244f22a010019f3ec12-f3c958/video_h1.m3u8"
}
