//
//  FTMediaProviderDownloadOperation.swift
//  FTPlayerView
//
//  Created by Stan Potemkin on 15.10.2024.
//

import Foundation
import FairyTurtle_Level_3

final class FTMediaProviderDownloadOperation: Operation {
    private let location: FTMediaPlaylistEntryLocation?
    private let contentDownloader: FTContentDownloader
    private let completion: (Data?) -> Void
    
    private let semaphore = DispatchSemaphore(value: 0)
    
    init(
        mapping: FTMediaPlaylistEntryLocation?,
        contentDownloader: FTContentDownloader,
        completion: @escaping (Data?) -> Void
    ) {
        self.location = mapping
        self.contentDownloader = contentDownloader
        self.completion = completion
    }
    
    override func main() {
        super.main()
        
        guard let location, !isCancelled else {
            return
        }
        
        defer {
            semaphore.wait()
        }
        
        print("HLS mapping operation")
        contentDownloader.request(
            url: location.url,
            range: location.range,
            receive: .online(completion: { [weak self] data in
                guard let self else {
                    return
                }
                
                if !isCancelled {
                    completion(data)
                }
                
                semaphore.signal()
            }))
    }
    
    override func cancel() {
        super.cancel()
        semaphore.signal()
    }
}
