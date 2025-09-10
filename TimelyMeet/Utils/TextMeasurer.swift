//
//  TextMeasurer.swift
//  TimelyMeet
//
//  Created on 02.09.2025.
//

import AppKit

enum MenuBarFont {
    static let base = NSFont.systemFont(ofSize: 12, weight: .medium)
}

struct TextMeasurer {
    static func width(_ string: String, font: NSFont = MenuBarFont.base) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        return (string as NSString).size(withAttributes: attrs).width.rounded(.up)
    }
}