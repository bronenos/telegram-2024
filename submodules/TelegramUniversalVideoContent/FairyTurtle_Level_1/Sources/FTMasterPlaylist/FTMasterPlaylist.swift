//
//  FTMasterPlaylist.swift
//  FTPlayerView
//
//  Created by Stan Potemkin on 06.10.2024.
//

import Foundation
import AVFoundation
import CoreMedia
import FairyTurtle_Level_3

protocol IFTMasterPlaylist: IFTMediaPlaylist {
    func availableMediaPlaylists() -> [FTMediaPlaylistInfo]
}

final class FTMasterPlaylist: FTMediaPlaylist, IFTMasterPlaylist {
    typealias Info = FTMasterPlaylistInfo
    
    private let supportedCodecs: Set<String>
    
    private var mediaPlaylists = [FTMediaPlaylist]()
    private var activeMediaPlaylist: FTMediaPlaylist?
    
    init(remoteUrl: URL, supportedCodecs: Set<String>, contentDownloader: FTContentDownloader) {
        self.supportedCodecs = supportedCodecs
        
        super.init(
            quality: 0,
            remoteUrl: remoteUrl,
            contentDownloader: contentDownloader)
    }
    
    func availableMediaPlaylists() -> [FTMediaPlaylistInfo] {
        return mediaPlaylists.compactMap(\.info)
    }
    
    override var info: FTMediaPlaylistInfo? {
        return activeMediaPlaylist?.info
    }
    
    override func prefetchInfo(completion: @escaping (FTMediaPlaylistInfo?) -> Void) {
        contentDownloader.request(
            url: remoteUrl,
            range: nil,
            receive: .cached(completion: { [weak self, supportedCodecs] localUrl in
                guard let self else {
                    return
                }
                
                guard let localUrl else {
                    return
                }
                
                guard let content = try? String(contentsOf: localUrl, encoding: .utf8) else {
                    return
                }
                
                if let _ = FTMediaPlaylistParser(quality: 0, content: content, baseUrl: remoteUrl).parse() {
                    mediaPlaylists = [
                        FTMediaPlaylist(quality: 0, remoteUrl: remoteUrl, contentDownloader: contentDownloader)
                    ]
                }
                else {
                    let info = FTMasterPlaylistParser(
                        content: content,
                        baseUrl: remoteUrl
                    ).parse()
                    
                    mediaPlaylists = info.streams
//                        .filter { stream in
//                            let codecs = stream.codecs.components(separatedBy: .punctuationCharacters)
//                            if Set(codecs).intersection(supportedCodecs) == supportedCodecs {
//                                return true
//                            }
//                            else {
//                                return false
//                            }
//                        }
                        .map { stream in
                            FTMediaPlaylist(
                                quality: stream.pixelHeight,
                                remoteUrl: stream.url,
                                contentDownloader: self.contentDownloader
                            )
                        }
                }
                
                DispatchQueue.main.async { [weak self] in
                    self?.prefetchChildren(completion: completion)
                }
            }))
    }
    
    override func requestSegments(since timestamp: TimeInterval) -> [FTMediaPlaylistSegment]{
        if let segments = activeMediaPlaylist?.requestSegments(since: timestamp) {
            return segments
        }
        else {
            return .ex_empty
        }
    }
    
    private func prefetchChildren(completion: @escaping (FTMediaPlaylistInfo?) -> Void) {
        let firstPlaylist = mediaPlaylists.first
        let otherMediaPlaylists = mediaPlaylists.dropFirst()
        
        activeMediaPlaylist = firstPlaylist
        activeMediaPlaylist?.prefetchInfo { info in
            completion(info)
            
            for playlist in otherMediaPlaylists {
                playlist.prefetchInfo()
            }
        }
    }
}
