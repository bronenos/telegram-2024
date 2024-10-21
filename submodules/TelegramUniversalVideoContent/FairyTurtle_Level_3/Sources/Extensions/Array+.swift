//
//  Array+.swift
//  FTPlayerView
//
//  Created by Stan Potemkin on 06.10.2024.
//

import Foundation

extension Array {
    static var ex_empty: Self {
        return Array()
    }
    
    var hasElements: Bool {
        return !isEmpty
    }
}
