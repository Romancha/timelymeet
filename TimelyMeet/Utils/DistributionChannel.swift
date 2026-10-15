//
//  DistributionChannel.swift
//  TimelyMeet
//
//  Detects whether the app was installed from the Mac App Store or downloaded directly (GitHub DMG)
//

import Foundation

enum DistributionChannel {
    case appStore
    case direct

    /// Mac App Store builds always ship with a receipt; Developer ID (DMG) and Xcode builds don't.
    /// Checked by path because `Bundle.appStoreReceiptURL` is deprecated since macOS 15.
    static let current: DistributionChannel = {
        let receiptPath = Bundle.main.bundleURL
            .appendingPathComponent("Contents/_MASReceipt/receipt")
            .path
        return FileManager.default.fileExists(atPath: receiptPath) ? .appStore : .direct
    }()

    static let appStoreURL = URL(string: "https://apps.apple.com/app/timelymeet/id6751949087")!
    static let repositoryURL = URL(string: "https://github.com/Romancha/timelymeet")!
    static let latestReleaseURL = URL(string: "https://github.com/Romancha/timelymeet/releases/latest")!

    var displayName: String {
        switch self {
        case .appStore: return "App Store"
        case .direct: return "GitHub"
        }
    }
}
