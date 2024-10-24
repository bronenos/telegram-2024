//
//  FTContentDownloader.swift
//  FTPlayerView
//
//  Created by Stan Potemkin on 06.10.2024.
//

import Foundation
import AVFoundation

public protocol IFTContentDownloader: AnyObject {
    func request(url: URL, range: Range<Int64>?, receive: FTContentReceiver)
}

public enum FTContentReceiver {
    case cached(completion: (URL?) -> Void)
    case online(completion: (Data?) -> Void)
}

public class FTContentDownloader: IFTContentDownloader {
    private let urlSession: URLSession
    private let fileManager: FileManager
    
    private let activeTasksMutex = NSLock()
    private var activeTasks = Dictionary<URL, URLSessionTask>()
    
    public init(urlSession: URLSession, fileManager: FileManager) {
        self.urlSession = urlSession
        self.fileManager = fileManager
    }
    
    public func request(url: URL, range: Range<Int64>?, receive: FTContentReceiver) {
        print("Download url \(url)")
        
        let localUrl = prepareLocalCachingPath(remoteUrl: url, range: range)
        
        switch receive {
        case .cached(let completion):
            if fileManager.fileExists(atPath: localUrl.relativePath) {
                completion(localUrl)
                return
            }
        case .online:
            break
        }
        
        var request = URLRequest(url: url)
        if let range, range.upperBound > 0 {
            request.setValue("bytes=\(range.lowerBound)-\(range.upperBound)", forHTTPHeaderField: "Range")
        }
        
        let task = urlSession.downloadTask(with: request) { [weak self] location, response, error in
            guard let self else {
                return
            }
            
            activeTasksMutex.lock()
            activeTasks.removeValue(forKey: url)
            activeTasksMutex.unlock()
            
            print()
            print("\(#function) request completed")
            print("> remote_url = \(url)")
            print("> remote_range = \((response?.ex_extractByteRange()).ornone())")
            print("> remote_error = \((error?.localizedDescription).ornone())")
            print("> local_tmp = \((location?.description).ornone())")
            print("> local_url = \(localUrl)")
            print()
            
            if let _ = error {
                switch receive {
                case .cached(let completion):
                    completion(nil)
                case .online(let completion):
                    completion(nil)
                }
                
                return
            }
            
            guard let location else {
                switch receive {
                case .cached(let completion):
                    completion(nil)
                case .online(let completion):
                    completion(nil)
                }
                
                return
            }
            
            do {
                switch receive {
                case .cached:
                    try fileManager.replaceItem(
                        at: localUrl,
                        withItemAt: location,
                        backupItemName: nil,
                        options: [],
                        resultingItemURL: nil)
                case .online:
                    break
                }
            }
            catch {
                switch receive {
                case .cached(let completion):
                    completion(nil)
                case .online(let completion):
                    completion(nil)
                }
                
                return
            }
            
            switch receive {
            case .cached(let completion):
//                if let data = try? Data(contentsOf: localUrl) {
//                    print("data size: \(data.count)")
//                }
                completion(localUrl)
            case .online(let completion):
                let data = try? Data(contentsOf: location)
                completion(data)
            }
        }
        
        activeTasksMutex.lock()
        activeTasks[url] = task
        activeTasksMutex.unlock()
        
        task.resume()
    }
    
    private func prepareLocalCachingPath(remoteUrl: URL, range: Range<Int64>?) -> URL {
        let prohibitedSymbols = CharacterSet(charactersIn: ":/?=#")
        let pathSlices = remoteUrl.relativePath.components(separatedBy: prohibitedSymbols)
        let pathPrefix = range.flatMap({ "\($0.lowerBound)_\($0.upperBound)_" }) ?? .ex_empty
        let pathSuffix = pathSlices.joined(separator: "_")
        
        let cachingDir: NSURL! = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("remote_content") as NSURL?
        let cachingUrl: NSURL! = cachingDir.appendingPathComponent("\(pathPrefix)_\(pathSuffix)") as NSURL?
        
        try? fileManager.createDirectory(at: cachingDir as URL, withIntermediateDirectories: true)
        try? fileManager.removeItem(at: cachingUrl as URL)
        
        return cachingUrl as URL
    }
}

fileprivate extension URLResponse {
    func ex_extractByteRange() -> String? {
        return (self as? HTTPURLResponse)?.allHeaderFields["Content-Range"] as? String
    }
}
