//
//  SystemInfo.swift
//  TimelyMeet
//
//  System information utilities
//

import Foundation

struct SystemInfo {
    /// Get Mac model identifier (e.g., "MacBookPro18,1")
    static func getMacModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &machine, &size, nil, 0)
        return String(cString: machine)
    }
    
    /// Generate system information string for support emails
    static func systemInfoString() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let systemVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let macModel = getMacModel()
        
        return """
        ---
        System Info:
        macOS: \(systemVersion)
        Model: \(macModel)
        App Version: \(version) (\(build))
        """
    }
}