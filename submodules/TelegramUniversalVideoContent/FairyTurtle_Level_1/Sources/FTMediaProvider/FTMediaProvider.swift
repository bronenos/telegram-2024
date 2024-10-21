//
//  FTMediaProvider.swift
//  FTPlayerView
//
//  Created by Stan Potemkin on 14.10.2024.
//

import Foundation
import FairyTurtle_Level_3

protocol IFTMediaProvider: AnyObject {
    var delegate: FTMediaProviderDelegate? { get set }
    func bindPlaylist(info: FTMediaPlaylistInfo)
    func preloadNext(current: TimeInterval, next: TimeInterval) -> TimeInterval
    func resetTo(timestamp: TimeInterval) -> TimeInterval
    func discardAll()
}

protocol FTMediaProviderDelegate: AnyObject {
    func mediaProvider(_ provider: IFTMediaProvider, fresh: Bool, mappingData: Data?, segmentsData: [FTMediaPlaylistSegmentContent])
}

final class FTMediaProvider: IFTMediaProvider {
    var delegate: FTMediaProviderDelegate?
    
    private let warmDuration: TimeInterval
    private let contentDownloader: FTContentDownloader
    
    private let downloadingOperationQueue = OperationQueue()
    private let decodingDispatchQueue = DispatchQueue(label: "ftplayer.queue.decoding", qos: .userInteractive)
    
    private var mappingOperation = Operation()
    private var readyOperation = Operation()
    
    private var info: FTMediaPlaylistInfo?
    private var requestingRange = IndexSet()
    private var cachedMappingData: Data?
    private var cachedSegmentsData = [Int: Data]()
    
    init(warmDuration: TimeInterval, contentDownloader: FTContentDownloader) {
        self.warmDuration = warmDuration
        self.contentDownloader = contentDownloader
        
        downloadingOperationQueue.name = "ftplayer.queue.downloading"
        downloadingOperationQueue.qualityOfService = .userInteractive
        downloadingOperationQueue.maxConcurrentOperationCount = 3
    }
    
    func bindPlaylist(info: FTMediaPlaylistInfo) {
        self.info = info
        
        requestingRange = IndexSet()
        cachedMappingData = nil
        cachedSegmentsData.removeAll()
        
        mappingOperation = makeMappingOperation(mapping: info.map)
        downloadingOperationQueue.cancelAllOperations()
        downloadingOperationQueue.addOperation(mappingOperation)
    }
    
    func preloadNext(current: TimeInterval, next: TimeInterval) -> TimeInterval {
        guard current >= next - warmDuration else {
            print("flow: provider: too early request at \(current)")
            return next
        }
        
        if let distant = preloadTimeRange(fresh: false, search: .starting(next)) {
            print("flow: provider: loading since \(next) until \(distant)")
            return distant
        }
        else {
            print("flow: provider: nothing to load")
            return next
        }
    }
    
    func resetTo(timestamp: TimeInterval) -> TimeInterval {
        requestingRange = IndexSet()
        downloadingOperationQueue.cancelAllOperations()
        
        if let distant = preloadTimeRange(fresh: true, search: .including(timestamp)) {
            return distant
        }
        else {
            return timestamp
        }
    }
    
    func discardAll() {
        downloadingOperationQueue.cancelAllOperations()
        cachedMappingData = nil
        cachedSegmentsData.removeAll()
    }
    
    private enum TimeRangeSearch {
        case starting(TimeInterval)
        case including(TimeInterval)
    }
    
    private func preloadTimeRange(fresh: Bool, search: TimeRangeSearch) -> TimeInterval? {
        guard let info else {
            return nil
        }
        
        let sinceFilter: (FTMediaPlaylistSegment) -> Bool
        let untilFilter: (FTMediaPlaylistSegment) -> Bool
        switch search {
        case .starting(let since):
            let lower = since
            let upper = since + warmDuration
            sinceFilter = { $0.since >= lower }
            untilFilter = { $0.since >= upper }
        case .including(let target):
            let lower = target
            let upper = target + warmDuration
            sinceFilter = { $0.since <= lower && lower < $0.until}
            untilFilter = { $0.since <= upper && upper < $0.until}
        }
        
        let sinceIndex = (info.segments.firstIndex(where: sinceFilter) ?? info.segments.startIndex)
        let untilIndex = (info.segments.firstIndex(where: untilFilter) ?? info.segments.endIndex)
        
        guard sinceIndex != untilIndex else {
            return nil
        }
        
        let segmentsRange = (sinceIndex ..< untilIndex)
        let segmentsIndices = IndexSet(integersIn: segmentsRange)
        guard !requestingRange.intersects(integersIn: segmentsRange) else {
            return nil
        }
        
        requestingRange = segmentsIndices
        
        readyOperation = makeReadyOperation(fresh: fresh, indices: segmentsIndices)
        readyOperation.addDependency(mappingOperation)
        defer {
            downloadingOperationQueue.addOperation(readyOperation)
        }
        
        for index in segmentsIndices {
            let segmentOperation = makeSegmentOperation(index: index, segment: info.segments[index])
            segmentOperation.addDependency(mappingOperation)
            readyOperation.addDependency(segmentOperation)
            downloadingOperationQueue.addOperation(segmentOperation)
        }
        
        let purgingLevel = max(info.segments.startIndex, segmentsRange.lowerBound - segmentsRange.count * 2)
        let cachedIndices = cachedSegmentsData.keys.filter { index in index < purgingLevel }
        for index in cachedIndices.sorted() {
            cachedSegmentsData.removeValue(forKey: index)
        }
        
        if segmentsIndices.isEmpty {
            return nil
        }
        else if let upperIndex = segmentsIndices.last {
            let upperSegment = info.segments[upperIndex]
            return upperSegment.until
        }
        else {
            return nil
        }
    }
    
    private func makeMappingOperation(mapping: FTMediaPlaylistEntryLocation?) -> Operation {
        FTMediaProviderDownloadOperation(
            mapping: mapping,
            contentDownloader: contentDownloader,
            completion: { [weak self] data in
                self?.cachedMappingData = data
            }
        )
    }
    
    private func makeSegmentOperation(index: Int, segment: FTMediaPlaylistSegment) -> Operation {
        FTMediaProviderDownloadOperation(
            mapping: segment.location,
            contentDownloader: contentDownloader,
            completion: { [weak self] data in
                self?.cachedSegmentsData[index] = data
            }
        )
    }
    
    private func makeReadyOperation(fresh: Bool, indices: IndexSet) -> Operation {
        FTMediaProviderSimpleOperation(
            completion: { [weak self] in
                guard let self, let info else {
                    return
                }
                
                requestingRange = IndexSet()
                
                let segments = cachedSegmentsData
                    .filter {
                        indices.contains($0.key)
                    }
                    .sorted { fst, snd in
                        fst.key < snd.key
                    }
                    .map { index, data in
                        FTMediaPlaylistSegmentContent(
                            segment: info.segments[index],
                            data: data
                        )
                    }
                
                delegate?.mediaProvider(
                    self,
                    fresh: fresh,
                    mappingData: cachedMappingData,
                    segmentsData: segments)
            }
        )
    }
}
