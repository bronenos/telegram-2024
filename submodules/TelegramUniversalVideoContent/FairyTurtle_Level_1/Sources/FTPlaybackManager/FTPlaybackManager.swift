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

public protocol IFTPlaybackManager: AnyObject {
    var currentTimestamp: Double { get }
    var volume: Double { get set }
    var rate: Double { get set }
    var currentHeight: Int { get }
    func bind(videoLayer: AVSampleBufferDisplayLayer)
    func bind(audioRenderer: AVSampleBufferAudioRenderer)
    func play(remoteUrl: URL)
    func availableQualities() -> [Int]
    func resume()
    func pause()
    func seekTo(timestamp ts: TimeInterval)
    func setQuality(_ value: Int?)
    func setSpeed(_ value: Double)
    func setVolume(_ value: Double)
    func startTesting()
}

public final class FTPlaybackManager: NSObject, IFTPlaybackManager, FTPlaybackFlightDelegate {
    private let contentDownloader: FTContentDownloader
    private let playbackFlight: FTPlaybackFlight
    
    private let mediaSynchronizer = AVSampleBufferRenderSynchronizer()
    private var videoLayer: AVSampleBufferDisplayLayer?
    private var audioRenderer: AVSampleBufferAudioRenderer?
    private var displayLink: CADisplayLink?
    
    private var masterPlaylist: FTMasterPlaylist?
    private let framesOperationQueue = DispatchQueue.global(qos: .userInteractive)
    private let framesMutex = NSLock()
    private var framesDeque = [FTPlaybackFrame]() // replace with Dequeue<FTPlaybackFrame>
    private var nextPreloadTime = TimeInterval.zero
    private var recentTimestamp = Double.zero
    private var recentRate = Float64(1.0)
    
    public var volume = Double.zero
    
    public var currentTimestamp: Double {
        return recentTimestamp
    }
    
    public var rate: Double {
        get {
            let result = Double(mediaSynchronizer.rate)
            return result
        }
        set {
            if newValue > 0 {
                recentRate = newValue
            }
            
            willChangeValue(forKey: "rate")
            mediaSynchronizer.rate = Float(newValue)
            didChangeValue(forKey: "rate")
        }
    }
    
    public override init() {
        contentDownloader = FTContentDownloader(
            urlSession: .shared,
            fileManager: .default
        )
        
        playbackFlight = FTPlaybackFlight(
            contentDownloader: contentDownloader
        )
        
        super.init()
        
        playbackFlight.delegate = self
    }
    
    public var currentHeight: Int {
        return playbackFlight.currentHeight
    }
        
    public func bind(videoLayer: AVSampleBufferDisplayLayer) {
        mediaSynchronizer.addRenderer(videoLayer)
        self.videoLayer = videoLayer
    }
    
    public func bind(audioRenderer: AVSampleBufferAudioRenderer) {
        mediaSynchronizer.addRenderer(audioRenderer)
        self.audioRenderer = audioRenderer
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
    }
    
    public func availableQualities() -> [Int] {
        if let playlists = masterPlaylist?.availableMediaPlaylists() {
            return playlists.map(\.quality)
        }
        else {
            return .ex_empty
        }
    }
    
    public func resume() {
        rate = recentRate
    }
    
    public func pause() {
        if rate > 0 {
            recentRate = rate
        }
        
        rate = 0
    }
    
    public func seekTo(timestamp ts: TimeInterval) {
        playbackFlight.seekTo(timestamp: ts)
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
        rate = value
    }
    
    public func setVolume(_ value: Double) {
        audioRenderer?.volume = Float(value)
    }
    
    public func startTesting() {
        enum TestingPlaylistUrl: String {
            static let primary = bipBop_master_fmp4_byterange
            case bipBop_master_fmp4_byterange = "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8"
            case bigBuckBunny_media_ts_timerange = "https://test-streams.mux.dev/x36xhzz/url_6/193039199_mp4_h264_aac_hq_7.m3u8"
            case homeMaster_h264_adts = "https://flipfit-cdn.akamaized.net/flip_hls/663d1244f22a010019f3ec12-f3c958/video_h1.m3u8"
        }
        
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
                recentTimestamp = frame.absoluteTimestamp
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
        
        mediaSynchronizer.setRate(1.0, time: CMTime.zero)
        recentRate = 1.0
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
