//
//  FTMediaProviderSimpleOperation.swift
//  FTPlayerView
//
//  Created by Stan Potemkin on 15.10.2024.
//

import Foundation

final class FTMediaProviderSimpleOperation: Operation {
    private let completion: () -> Void
    
    init(
        completion: @escaping () -> Void
    ) {
        self.completion = completion
    }
    
    override func main() {
        super.main()
        
        if !isCancelled {
            completion()
        }
    }
}
