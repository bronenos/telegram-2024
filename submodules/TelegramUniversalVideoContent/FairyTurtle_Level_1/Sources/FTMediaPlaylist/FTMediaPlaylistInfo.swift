//
//  FTMediaPlaylistInfo.swift
//  FTPlayerView
//
//  Created by Stan Potemkin on 06.10.2024.
//

import Foundation

struct FTMediaPlaylistInfo {
    let quality: Int
    let url: URL
    let map: FTMediaPlaylistEntryLocation? 
    var segments: [FTMediaPlaylistSegment]
}

struct FTMediaPlaylistEntryLocation: Hashable {
    let url: URL
    let range: Range<Int64>?
}

struct FTMediaPlaylistSegment: Hashable {
    let location: FTMediaPlaylistEntryLocation
    let duration: TimeInterval
    let since: TimeInterval
    let until: TimeInterval
}

struct FTMediaPlaylistSegmentContent {
    let segment: FTMediaPlaylistSegment
    let data: Data
}
