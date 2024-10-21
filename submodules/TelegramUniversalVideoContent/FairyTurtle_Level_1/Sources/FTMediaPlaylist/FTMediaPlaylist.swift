//
//  FTMediaPlaylist.swift
//  FTPlayerView
//
//  Created by Stan Potemkin on 06.10.2024.
//

import Foundation
import FairyTurtle_Level_3

protocol IFTMediaPlaylist: AnyObject {
    var info: FTMediaPlaylistInfo? { get }
    func prefetchInfo(completion: @escaping (FTMediaPlaylistInfo?) -> Void)
    func requestSegments(since timestamp: TimeInterval) -> [FTMediaPlaylistSegment]
}

open class FTMediaPlaylist: IFTMediaPlaylist {
    typealias Info = FTMediaPlaylistInfo
    
    let quality: Int
    let remoteUrl: URL
    let contentDownloader: FTContentDownloader
    
    private(set) var info: FTMediaPlaylistInfo?
    
    init(quality: Int, remoteUrl: URL, contentDownloader: FTContentDownloader) {
        self.quality = quality
        self.remoteUrl = remoteUrl
        self.contentDownloader = contentDownloader
    }
    
    func prefetchInfo(completion: @escaping (FTMediaPlaylistInfo?) -> Void = { _ in }) {
        contentDownloader.request(
            url: remoteUrl,
            range: nil,
            receive: .cached(completion: { [weak self] localUrl in
                guard let self else {
                    return
                }
                
                guard let localUrl else {
                    return
                }
                
                guard let content = try? String(contentsOf: localUrl, encoding: .utf8) else {
                    return
                }
                
                info = FTMediaPlaylistParser(
                    quality: quality,
                    content: content,
                    baseUrl: remoteUrl
                ).parse()
                
                completion(info)
            }))
    }
    
    func requestSegments(since timestamp: TimeInterval) -> [FTMediaPlaylistSegment] {
        if let info {
            return info.segments.filter { $0.since >= timestamp }
        }
        else {
            return .ex_empty
        }
    }
}
