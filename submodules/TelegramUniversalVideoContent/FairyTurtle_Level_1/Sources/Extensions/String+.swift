//
//  String+.swift
//  FTPlayerView
//
//  Created by Stan Potemkin on 06.10.2024.
//

import Foundation

extension String {
    static var ex_empty = String()
    static var ex_newline = "\n"
    
    func ns() -> NSString {
        return NSString(string: self)
    }
    
    subscript(_ range: NSRange) -> String {
        return (self as NSString).substring(with: range)
    }
    
    var notEmpty: Bool {
        return !isEmpty
    }
    
    func find(_ substring: String) -> Index? {
        let range = ns().range(of: substring)
        if range.location == NSNotFound {
            return nil
        }
        else {
            return index(startIndex, offsetBy: range.location)
        }
    }
}

extension Optional where Wrapped == String {
    func ornone() -> String {
        return self ?? "none"
    }
}
