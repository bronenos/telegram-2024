//
//  FTMasterPlaylistParser.swift
//  FTPlayerView
//
//  Created by Stan Potemkin on 06.10.2024.
//

import Foundation

fileprivate let f_tag_prefix = "#"
fileprivate let f_ext_prefix = f_tag_prefix + "EXT"
fileprivate let f_val_separator = Character(":")
fileprivate let f_prefix_EXT_X_STREAM_INF = f_tag_prefix + "EXT-X-STREAM-INF" + String(f_val_separator) 

struct FTMasterPlaylistParser {
    let content: String
    let baseUrl: URL
    
    func parse() -> FTMasterPlaylistInfo {
        var streams = [FTMasterPlaylistInfoStream]()
        
        var scanned = Scanned.empty
        struct Scanned: Hashable {
            static let empty = Self.init()
            var isDirty: Bool { self == .empty }
            var tags = [String]()
            var value = String()
        }
        
        func _flushIfNeeded() {
            scanned.tags.forEach { tag in
                if tag.hasPrefix(f_prefix_EXT_X_STREAM_INF) {
                    guard let regex = try? NSRegularExpression(pattern: "\\b([A-Z-]+)\\b=([^\"][^,]+|[\"][^\"]+\")") else {
                        return
                    }
                    
                    let url = baseUrl.deletingLastPathComponent().appendingPathComponent(scanned.value)
                    var bandwidth = Int.zero
                    var codecs = String()
                    var pixelWidth = Int.zero
                    var pixelHeight = Int.zero
                    
                    let range = NSMakeRange(f_prefix_EXT_X_STREAM_INF.count, tag.count - f_prefix_EXT_X_STREAM_INF.count)
                    let matches = regex.matches(in: tag, range: range)
                    for match in matches {
                        let paramKeyRaw = tag[match.range(at: 1)]
                        let paramKey = paramKeyRaw.lowercased()
                        
                        let paramValueRaw = tag[match.range(at: 2)]
                        let paramValue = paramValueRaw.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                        
                        switch paramKey {
                        case "bandwidth":
                            bandwidth = (paramValue as NSString).integerValue
                        case "codecs":
                            codecs = paramValue
                        case "resolution":
                            let dimensions = paramValue.components(separatedBy: "x")
                            pixelWidth = NSString(string: dimensions.first ?? .ex_empty).integerValue
                            pixelHeight = NSString(string: dimensions.last ?? .ex_empty).integerValue
                        default:
                            break
                        }
                    }
                    
                    streams.append(FTMasterPlaylistInfoStream(
                        bandWidth: bandwidth,
                        codecs: codecs,
                        pixelWidth: pixelWidth,
                        pixelHeight: pixelHeight,
                        url: url
                    ))
                }
            }
            
            scanned = .empty
        }
        
        let scanner = Scanner(string: content)
        while (scanner.canRead || scanned.isDirty) {
            guard let line = scanner.scanLine() else {
                _flushIfNeeded()
                break
            }
            
            if line.hasPrefix(f_ext_prefix) {
                _flushIfNeeded()
                scanned.tags.append(line)
            }
            else if line.isEmpty {
                _flushIfNeeded()
            }
            else if !line.hasPrefix(f_tag_prefix) {
                scanned.value = line
            }
        }
        
        streams.sort { fst, snd in
            if fst.bandWidth < snd.bandWidth {
                return  true
            }
            else if fst.pixelHeight < snd.pixelHeight {
                return true
            }
            else {
                return false
            }
        }
        
        return FTMasterPlaylistInfo(
            streams: streams
        )
    }
}
