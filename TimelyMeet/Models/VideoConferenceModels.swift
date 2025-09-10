//
//  VideoConferenceModels.swift  
//  TimelyMeet
//

import Foundation
import SwiftUI

// MARK: - Enhanced Models per Technical Specification

/// Configuration for video conference provider behavior
struct ProviderConfig: Codable {
    let provider: VideoConferencePlatform
    let hasDeeplink: Bool
    let deeplinkScheme: String?
    let requiresWebFallback: Bool
    let specialHandling: [String] // e.g., ["personal_rooms_web_only"] for Zoom
    let recommendedStrategy: OpeningStrategy // Developer-recommended default strategy
    let recommendedBrowser: BrowserChoice // Developer-recommended default browser
    
    static let configs: [VideoConferencePlatform: ProviderConfig] = [
        .zoom: ProviderConfig(
            provider: .zoom,
            hasDeeplink: true,
            deeplinkScheme: "zoommtg",
            requiresWebFallback: true,
            specialHandling: ["personal_rooms_web_only"],
            recommendedStrategy: .preferApp,
            recommendedBrowser: .system
        ),
        .teams: ProviderConfig(
            provider: .teams,
            hasDeeplink: true,
            deeplinkScheme: "msteams",
            requiresWebFallback: true,
            specialHandling: [],
            recommendedStrategy: .preferApp,
            recommendedBrowser: .system
        ),
        .meet: ProviderConfig(
            provider: .meet,
            hasDeeplink: false,
            deeplinkScheme: nil,
            requiresWebFallback: true,
            specialHandling: ["universal_links_only"],
            recommendedStrategy: .alwaysWeb,
            recommendedBrowser: .system
        ),
        .jitsi: ProviderConfig(
            provider: .jitsi,
            hasDeeplink: true,
            deeplinkScheme: "org.jitsi.meet",
            requiresWebFallback: true,
            specialHandling: ["mobile_only_scheme"],
            recommendedStrategy: .alwaysWeb,
            recommendedBrowser: .system
        ),
        .slack: ProviderConfig(
            provider: .slack,
            hasDeeplink: true,
            deeplinkScheme: "slack",
            requiresWebFallback: true,
            specialHandling: [],
            recommendedStrategy: .preferApp,
            recommendedBrowser: .system
        ),
        .webex: ProviderConfig(
            provider: .webex,
            hasDeeplink: false,
            deeplinkScheme: nil,
            requiresWebFallback: true,
            specialHandling: ["meetings_web_only"],
            recommendedStrategy: .alwaysWeb,
            recommendedBrowser: .system
        ),
        .ringcentral: ProviderConfig(
            provider: .ringcentral,
            hasDeeplink: false,
            deeplinkScheme: nil,
            requiresWebFallback: true,
            specialHandling: ["web_deeplink_only"],
            recommendedStrategy: .alwaysWeb,
            recommendedBrowser: .system
        ),
        .skype: ProviderConfig(
            provider: .skype,
            hasDeeplink: true,
            deeplinkScheme: "skype",
            requiresWebFallback: true,
            specialHandling: [],
            recommendedStrategy: .preferApp,
            recommendedBrowser: .system
        ),
        .facetime: ProviderConfig(
            provider: .facetime,
            hasDeeplink: false,
            deeplinkScheme: nil,
            requiresWebFallback: true,
            specialHandling: ["system_handler"],
            recommendedStrategy: .systemDefault,
            recommendedBrowser: .system
        ),
        .telemost: ProviderConfig(
            provider: .telemost,
            hasDeeplink: true,
            deeplinkScheme: "telemost",
            requiresWebFallback: true,
            specialHandling: [],
            recommendedStrategy: .preferApp,
            recommendedBrowser: .system
        ),
        .dion: ProviderConfig(
            provider: .dion,
            hasDeeplink: false,
            deeplinkScheme: nil,
            requiresWebFallback: true,
            specialHandling: [],
            recommendedStrategy: .alwaysWeb,
            recommendedBrowser: .chrome
        ),
        .discord: ProviderConfig(
            provider: .discord,
            hasDeeplink: true,
            deeplinkScheme: "discord",
            requiresWebFallback: true,
            specialHandling: [],
            recommendedStrategy: .preferApp,
            recommendedBrowser: .system
        ),
        .whatsapp: ProviderConfig(
            provider: .whatsapp,
            hasDeeplink: false,
            deeplinkScheme: nil,
            requiresWebFallback: true,
            specialHandling: [],
            recommendedStrategy: .alwaysWeb,
            recommendedBrowser: .system
        ),
        .telegram: ProviderConfig(
            provider: .telegram,
            hasDeeplink: true,
            deeplinkScheme: "tg",
            requiresWebFallback: true,
            specialHandling: [],
            recommendedStrategy: .preferApp,
            recommendedBrowser: .system
        ),
        .whereby: ProviderConfig(
            provider: .whereby,
            hasDeeplink: false,
            deeplinkScheme: nil,
            requiresWebFallback: true,
            specialHandling: [],
            recommendedStrategy: .alwaysWeb,
            recommendedBrowser: .system
        ),
        .around: ProviderConfig(
            provider: .around,
            hasDeeplink: false,
            deeplinkScheme: nil,
            requiresWebFallback: true,
            specialHandling: [],
            recommendedStrategy: .alwaysWeb,
            recommendedBrowser: .system
        ),
        .gather: ProviderConfig(
            provider: .gather,
            hasDeeplink: false,
            deeplinkScheme: nil,
            requiresWebFallback: true,
            specialHandling: [],
            recommendedStrategy: .alwaysWeb,
            recommendedBrowser: .system
        ),
        .luma: ProviderConfig(
            provider: .luma,
            hasDeeplink: false,
            deeplinkScheme: nil,
            requiresWebFallback: true,
            specialHandling: [],
            recommendedStrategy: .alwaysWeb,
            recommendedBrowser: .system
        ),
        .gotomeeting: ProviderConfig(
            provider: .gotomeeting,
            hasDeeplink: false,
            deeplinkScheme: nil,
            requiresWebFallback: true,
            specialHandling: [],
            recommendedStrategy: .alwaysWeb,
            recommendedBrowser: .system
        ),
        .bluejeans: ProviderConfig(
            provider: .bluejeans,
            hasDeeplink: false,
            deeplinkScheme: nil,
            requiresWebFallback: true,
            specialHandling: [],
            recommendedStrategy: .alwaysWeb,
            recommendedBrowser: .system
        ),
        .chime: ProviderConfig(
            provider: .chime,
            hasDeeplink: false,
            deeplinkScheme: nil,
            requiresWebFallback: true,
            specialHandling: [],
            recommendedStrategy: .alwaysWeb,
            recommendedBrowser: .system
        ),
        .vonage: ProviderConfig(
            provider: .vonage,
            hasDeeplink: false,
            deeplinkScheme: nil,
            requiresWebFallback: true,
            specialHandling: [],
            recommendedStrategy: .alwaysWeb,
            recommendedBrowser: .system
        ),
        .vkcalls: ProviderConfig(
            provider: .vkcalls,
            hasDeeplink: true,
            deeplinkScheme: "vkcalls",
            requiresWebFallback: true,
            specialHandling: [],
            recommendedStrategy: .preferApp,
            recommendedBrowser: .system
        )
    ]
}

/// User preference for opening meeting links
enum OpeningStrategy: String, CaseIterable, Codable {
    case preferApp = "prefer_app"
    case alwaysWeb = "always_web"
    case specificBrowser = "specific_browser"
    case systemDefault = "system_default"
    
    var displayName: String {
        switch self {
        case .preferApp: return "Prefer Application"
        case .alwaysWeb: return "Always Web Browser"
        case .specificBrowser: return "Specific Browser"
        case .systemDefault: return "System Default"
        }
    }
}

/// Available browsers for opening web links
enum BrowserChoice: String, CaseIterable, Codable {
    case system = "system"
    case safari = "safari"
    case chrome = "chrome"
    case firefox = "firefox"
    case edge = "edge"
    case opera = "opera"
    case arc = "arc"
    
    var displayName: String {
        switch self {
        case .system: return "System Default"
        case .safari: return "Safari"
        case .chrome: return "Google Chrome"
        case .firefox: return "Firefox"
        case .edge: return "Microsoft Edge"
        case .opera: return "Opera"
        case .arc: return "Arc"
        }
    }
    
    var bundleIdentifier: String? {
        switch self {
        case .system: return nil
        case .safari: return "com.apple.Safari"
        case .chrome: return "com.google.Chrome"
        case .firefox: return "org.mozilla.firefox"
        case .edge: return "com.microsoft.edgemac"
        case .opera: return "com.operasoftware.Opera"
        case .arc: return "company.thebrowser.Browser"
        }
    }
}

/// Result of opening attempt for telemetry
enum OpenResult: String, Codable {
    case opened = "opened"
    case fallback = "fallback"
    case noHandler = "no_handler"
    case error = "error"
}

/// Enhanced video conference info with normalized data
struct EnhancedVideoConferenceInfo {
    let platform: VideoConferencePlatform
    let originalUrl: URL
    let normalizedUrl: URL
    let displayName: String
    let config: ProviderConfig
    let extractedParameters: [String: String]
    
    init(platform: VideoConferencePlatform, originalUrl: URL, normalizedUrl: URL, displayName: String, extractedParameters: [String: String] = [:]) {
        self.platform = platform
        self.originalUrl = originalUrl
        self.normalizedUrl = normalizedUrl
        self.displayName = displayName
        self.config = ProviderConfig.configs[platform] ?? ProviderConfig(
            provider: platform,
            hasDeeplink: false,
            deeplinkScheme: nil,
            requiresWebFallback: true,
            specialHandling: [],
            recommendedStrategy: .systemDefault,
            recommendedBrowser: .system
        )
        self.extractedParameters = extractedParameters
    }
}

/// Telemetry event for meeting opening attempts
struct MeetingOpenEvent {
    let provider: VideoConferencePlatform
    let openType: String // "app" or "web"
    let result: OpenResult
    let timestamp: Date
    let hasHandler: Bool?
    let errorCode: String?
    
    init(provider: VideoConferencePlatform, openType: String, result: OpenResult, hasHandler: Bool? = nil, errorCode: String? = nil) {
        self.provider = provider
        self.openType = openType
        self.result = result
        self.timestamp = Date()
        self.hasHandler = hasHandler
        self.errorCode = errorCode
    }
}

/// User preferences for video conference handling
@MainActor
class VideoConferencePreferences: ObservableObject {
    @Published var providerStrategies: [VideoConferencePlatform: OpeningStrategy] = [:]
    @Published var providerBrowsers: [VideoConferencePlatform: BrowserChoice] = [:]
    
    private let userDefaults = UserDefaults.standard
    
    init() {
        loadPreferences()
    }
    
    func strategyFor(provider: VideoConferencePlatform) -> OpeningStrategy {
        // Priority: 1. Provider-specific setting 2. Provider recommendation
        return providerStrategies[provider] ?? recommendedStrategyFor(provider: provider)
    }
    
    func browserFor(provider: VideoConferencePlatform) -> BrowserChoice {
        // Priority: 1. Provider-specific setting 2. Provider recommendation (system default for unknown)
        return providerBrowsers[provider] ?? recommendedBrowserFor(provider: provider)
    }
    
    func recommendedStrategyFor(provider: VideoConferencePlatform) -> OpeningStrategy {
        return ProviderConfig.configs[provider]?.recommendedStrategy ?? .systemDefault
    }
    
    func recommendedBrowserFor(provider: VideoConferencePlatform) -> BrowserChoice {
        return ProviderConfig.configs[provider]?.recommendedBrowser ?? .system
    }
    
    func resetToRecommended(for provider: VideoConferencePlatform) {
        // Remove provider-specific overrides to use recommended defaults
        providerStrategies.removeValue(forKey: provider)
        providerBrowsers.removeValue(forKey: provider)
        
        savePreferences()
    }
    
    func setStrategy(_ strategy: OpeningStrategy, for provider: VideoConferencePlatform) {
        providerStrategies[provider] = strategy
        savePreferences()
    }
    
    func setBrowser(_ browser: BrowserChoice, for provider: VideoConferencePlatform) {
        providerBrowsers[provider] = browser
        savePreferences()
    }
    
    private func loadPreferences() {
        // Load provider-specific strategies
        if let data = userDefaults.data(forKey: "videoconference_provider_strategies"),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            providerStrategies = Dictionary(uniqueKeysWithValues: 
                decoded.compactMap { key, value in
                    guard let platform = VideoConferencePlatform.allCases.first(where: { $0.rawValue == key }),
                          let strategy = OpeningStrategy(rawValue: value) else { return nil }
                    return (platform, strategy)
                }
            )
        }
        
        // Load provider-specific browsers
        if let data = userDefaults.data(forKey: "videoconference_provider_browsers"),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            providerBrowsers = Dictionary(uniqueKeysWithValues: 
                decoded.compactMap { key, value in
                    guard let platform = VideoConferencePlatform.allCases.first(where: { $0.rawValue == key }),
                          let browser = BrowserChoice(rawValue: value) else { return nil }
                    return (platform, browser)
                }
            )
        }
    }
    
    func savePreferences() {
        // Save provider strategies
        let encodedStrategies = Dictionary(uniqueKeysWithValues: 
            providerStrategies.map { key, value in (key.rawValue, value.rawValue) }
        )
        if let data = try? JSONEncoder().encode(encodedStrategies) {
            userDefaults.set(data, forKey: "videoconference_provider_strategies")
        }
        
        // Save provider browsers
        let encodedBrowsers = Dictionary(uniqueKeysWithValues: 
            providerBrowsers.map { key, value in (key.rawValue, value.rawValue) }
        )
        if let data = try? JSONEncoder().encode(encodedBrowsers) {
            userDefaults.set(data, forKey: "videoconference_provider_browsers")
        }
    }
}
