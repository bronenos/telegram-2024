//
//  FTMasterPlaylistInfo.swift
//  FTPlayerView
//
//  Created by Stan Potemkin on 06.10.2024.
//

import Foundation

struct FTMasterPlaylistInfo {
    let streams: [FTMasterPlaylistInfoStream]
}

struct FTMasterPlaylistInfoStream {
    let bandWidth: Int
    let codecs: String
    let pixelWidth: Int
    let pixelHeight: Int
    let url: URL
}
