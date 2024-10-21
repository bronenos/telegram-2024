//
//  FTMediaPlaylistParser.swift
//  FTPlayerView
//
//  Created by Stan Potemkin on 06.10.2024.
//

import Foundation

fileprivate let f_tag_prefix = "#"
fileprivate let f_ext_prefix = f_tag_prefix + "EXT"
fileprivate let f_val_separator = Character(":")
fileprivate let f_prefix_EXTINF = f_tag_prefix + "EXTINF" + String(f_val_separator) 
fileprivate let f_prefix_EXT_X_MAP = f_tag_prefix + "EXT-X-MAP" + String(f_val_separator) 
fileprivate let f_prefix_EXT_X_BYTERANGE = f_tag_prefix + "EXT-X-BYTERANGE" + String(f_val_separator) 

//final class FTMediaPlaylistParser: IFTMediaPlaylistParser {
//    private let fScanningExtPrefix = "#EXT"
//    
//    static func parse(content: String, baseUrl: URL) -> FTMediaPlaylistInfo {
//        preconditionFailure()
//        
//        var info = FTMediaPlaylistInfo(url: baseUrl, segments: [])
//        let scanner = Scanner(string: content)
//        
//        var key = String(), params = String()
//        var values = [String]()
//        var totalDuration = TimeInterval.zero
//        
//        func _flushIfNeeded() {
//            if key == "INF" {
//                let regex = try? NSRegularExpression(pattern: "^[0-9.]+")
//                guard let regex else {
//                    return
//                }
//                
//                let range = NSRange(location: 0, length: params.count)
//                guard let firstMatch = regex.firstMatch(in: params, range: range) else {
//                    return
//                }
//                
//                guard let path = values.first else {
//                    return
//                }
//                
//                let url = baseUrl.deletingLastPathComponent().appendingPathComponent(path, conformingTo: .directory)
//                let duration = params.ns().substring(with: firstMatch.range).ns().doubleValue
//                
//                let segment = FTMediaPlaylistInfoSegment(
//                    url: url,
//                    duration: duration,
//                    sinceTimestamp: totalDuration,
//                    untilTimestamp: totalDuration + duration 
//                )
//                
//                info.segments.append(segment)
//                totalDuration = segment.untilTimestamp
//            }
//            
//            key = String()
//            params = String()
//            values.removeAll()
//        }
//    }
//}

struct FTMediaPlaylistParser {
    let quality: Int
    let content: String
    let baseUrl: URL
    
    func parse() -> FTMediaPlaylistInfo? {
        guard let _ = content.find(f_prefix_EXTINF) else {
            return nil
        }
        
        var map: FTMediaPlaylistEntryLocation?
        var segments = [FTMediaPlaylistSegment]()
        var totalOffset = Int64.zero
        var totalDuration = TimeInterval.zero
        
        var scanned = Scanned.empty
        struct Scanned: Hashable {
            static let empty = Scanned()
            var isDirty: Bool { self == .empty }
            var tags = [String]()
            var value = String()
        }
        
        func _flushIfNeeded() {
            guard scanned.value.notEmpty else {
                return
            }
            
            var anyUri = String()
            var anyOffset = Int64.zero
            var anyLength = Int64.zero
            var anyDuration = TimeInterval.zero
            
            scanned.tags.forEach { tag in
                if tag.hasPrefix(f_prefix_EXT_X_MAP) {
                    anyUri = String()
                    anyOffset = .zero
                    anyLength = .zero
                    
                    guard let regex = try? NSRegularExpression(pattern: "\\b([A-Z-]+)\\b=([\"][^\"]+\")") else {
                        return
                    }
                    
                    let range = NSMakeRange(f_prefix_EXT_X_MAP.count, tag.count - f_prefix_EXT_X_MAP.count)
                    let matches = regex.matches(in: tag, range: range)
                    for match in matches {
                        let paramKeyRaw = tag[match.range(at: 1)]
                        let paramKey = paramKeyRaw
                        
                        let paramValueRaw = tag[match.range(at: 2)]
                        let paramValue = paramValueRaw.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                        
                        switch paramKey {
                        case "URI":
                            anyUri = paramValue
                        case "BYTERANGE":
                            let args = paramValue.components(separatedBy: "@")
                            anyOffset = (args.count > 1 ? NSString(string: args.last ?? .ex_empty).longLongValue : 0)
                            anyLength = NSString(string: args.first ?? .ex_empty).longLongValue
                        default:
                            break
                        }
                    }
                    
                    if anyUri.notEmpty {
                        let url = baseUrl.deletingLastPathComponent().appendingPathComponent(anyUri)
                        let range = (anyOffset)..<(anyOffset + anyLength)
                        map = FTMediaPlaylistEntryLocation(url: url, range: range)
                    }
                    
                    totalOffset += anyOffset
                }
                else if tag.hasPrefix(f_prefix_EXTINF) {
                    guard let regex = try? NSRegularExpression(pattern: "^[0-9.]+") else {
                        return
                    }
                    
                    let range = NSMakeRange(f_prefix_EXTINF.count, tag.count - f_prefix_EXTINF.count)
                    if let firstMatch = regex.firstMatch(in: tag, range: range) {
                        anyDuration = (tag[firstMatch.range] as NSString).doubleValue
                    }
                }
                else if tag.hasPrefix(f_prefix_EXT_X_BYTERANGE) {
                    guard let regex = try? NSRegularExpression(pattern: "([0-9]+)(?:@([0-9]+))") else {
                        return
                    }
                    
                    let range = NSMakeRange(f_prefix_EXT_X_BYTERANGE.count, tag.count - f_prefix_EXT_X_BYTERANGE.count)
                    if let firstMatch = regex.firstMatch(in: tag, range: range) {
                        anyOffset = (tag[firstMatch.range(at: 2)] as NSString).longLongValue
                        anyLength = (tag[firstMatch.range(at: 1)] as NSString).longLongValue
                    }
                }
            }
            
            if scanned.value.notEmpty {
                let url = baseUrl.deletingLastPathComponent().appendingPathComponent(scanned.value)
                let offset = (anyOffset == .zero ? totalOffset : anyOffset)
                let range = (offset)..<(offset + anyLength)
                
                let segment = FTMediaPlaylistSegment(
                    location: FTMediaPlaylistEntryLocation(url: url, range: range),
                    duration: anyDuration,
                    since: totalDuration,
                    until: totalDuration + anyDuration
                )
                
                totalOffset = offset + anyLength
                totalDuration = segment.until
                segments.append(segment)
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
                scanned.tags.append(line)
            }
            else if line.isEmpty {
                _flushIfNeeded()
            }
            else if !line.hasPrefix(f_tag_prefix) {
                scanned.value = line
                _flushIfNeeded()
            }
        }
        
        return FTMediaPlaylistInfo(
            quality: quality,
            url: baseUrl,
            map: map,
            segments: segments
        )
    }
}
