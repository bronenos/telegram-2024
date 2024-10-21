//
//  Scanner+.swift
//  FTPlayerView
//
//  Created by Stan Potemkin on 06.10.2024.
//

import Foundation

extension Scanner {
    func scanLine() -> String? {
        var output: NSString?
        scanUpTo(.ex_newline, into: &output)
        scanString(.ex_newline, into: nil)
        return output as String?
    }
    
    var canRead: Bool {
        return !isAtEnd
    }
}
