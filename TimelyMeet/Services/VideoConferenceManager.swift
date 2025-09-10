//
//  VideoConferenceManager.swift
//  TimelyMeet
//
//  Enhanced version implementing Technical Specification requirements
//

import Foundation
import AppKit
import EventKit
import OSLog

@MainActor
class VideoConferenceManager: ObservableObject {
    
    private let logger = Logger(subsystem: "org.romancha.timelymeet", category: "VideoConferenceManager")
    private let urlNormalizer = URLNormalizer()
    private let providers = EnhancedProviders()
    private let preferences = VideoConferencePreferences()
    
    private var telemetryEvents: [MeetingOpenEvent] = []
    
    /// Enhanced extraction with URL normalization and provider detection per TS
    func extractEnhancedVideoConferenceInfo(from event: EKEvent) -> EnhancedVideoConferenceInfo? {
        let combinedText = "\(event.title ?? "") \(event.notes ?? "") \(event.location ?? "")"
        
        // Extract all URLs from event text
        let urls = extractURLs(from: combinedText)
        
        for url in urls {
            do {
                // 1. Normalize URL (remove Safe Links, clean tracking)
                let normalizedURL = try urlNormalizer.normalize(url)
                
                // 2. Detect provider using whitelist approach
                if let platform = providers.detectProvider(from: normalizedURL) {
                    
                    // 3. Extract parameters for deeplink generation
                    let parameters = extractParameters(from: normalizedURL, platform: platform)
                    
                    let displayName = platform.rawValue
                    
                    return EnhancedVideoConferenceInfo(
                        platform: platform,
                        originalUrl: url,
                        normalizedUrl: normalizedURL,
                        displayName: "Join \(displayName)",
                        extractedParameters: parameters
                    )
                }
            } catch {
                logger.error("Failed to normalize URL \(url.absoluteString): \(error.localizedDescription)")
                continue
            }
        }
        
        return nil
    }
    
    private func extractURLs(from text: String) -> [URL] {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) ?? []
        
        return matches.compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            let urlString = String(text[range])
            return URL(string: urlString)
        }
    }
    
    private func extractParameters(from url: URL, platform: VideoConferencePlatform) -> [String: String] {
        var parameters: [String: String] = [:]
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return parameters
        }
        
        // Extract platform-specific parameters
        switch platform {
        case .zoom:
            if let pwd = queryItems.first(where: { $0.name == "pwd" })?.value {
                parameters["pwd"] = pwd
            }
            // Extract meeting ID from path
            if url.path.starts(with: "/j/") {
                let meetingID = String(url.path.dropFirst(3)).components(separatedBy: "?")[0]
                parameters["meetingId"] = meetingID
            }
        default:
            break
        }
        
        return parameters
    }
    
    /// Legacy method for backward compatibility
    func extractVideoConferenceInfo(from event: EKEvent) -> VideoConferenceInfo? {
        guard let enhanced = extractEnhancedVideoConferenceInfo(from: event) else { return nil }
        return VideoConferenceInfo(
            platform: enhanced.platform,
            url: enhanced.normalizedUrl,
            displayName: enhanced.displayName
        )
    }
    
    /// Enhanced meeting joining with proper strategy handling and telemetry
    func joinMeeting(url: URL) async throws {
        
        do {
            // 1. Validate and normalize URL
            try SecurityValidator().validateURL(url)
            let normalizedURL = try urlNormalizer.normalize(url)
            
            // 2. Detect provider
            guard let platform = providers.detectProvider(from: normalizedURL) else {
                throw VideoConferenceError.invalidURL("Unsupported video conference provider")
            }
            
            // 3. Create enhanced info
            let parameters = extractParameters(from: normalizedURL, platform: platform)
            let info = EnhancedVideoConferenceInfo(
                platform: platform,
                originalUrl: url,
                normalizedUrl: normalizedURL,
                displayName: "Join \(platform.rawValue)",
                extractedParameters: parameters
            )
            
            // 4. Get user strategy
            let strategy = preferences.strategyFor(provider: platform)
            
            // 5. Check for forced web fallback
            if providers.shouldForceWebFallback(for: info) || strategy == .alwaysWeb {
                try await openInWeb(info: info)
                    return
            }
            
            // 6. Try deeplink if available and preferred
            if strategy == .preferApp || strategy == .systemDefault {
                if let deeplinkURL = providers.generateDeeplink(for: info, strategy: strategy) {
                    logger.debug("Attempting deeplink: \(deeplinkURL.absoluteString)")
                    
                    // Check if handler exists
                    let hasHandler = await checkSchemeHandler(for: deeplinkURL)
                    
                    if hasHandler {
                        do {
                            try await openURL(deeplinkURL, promptUser: false)
                            logger.info("Successfully opened deeplink: \(deeplinkURL.absoluteString)")
                            
                            
                            return
                        } catch {
                            logger.warning("Deeplink failed: \(error.localizedDescription)")
                        }
                    } else {
                        logger.debug("No handler found for scheme: \(deeplinkURL.scheme ?? "unknown")")
                    }
                }
            }
            
            // 7. Web fallback
            try await openInWeb(info: info)
            logger.info("Opened in web browser: \(info.normalizedUrl.absoluteString)")
            
        } catch {
            logger.error("Failed to join meeting: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func openInWeb(info: EnhancedVideoConferenceInfo) async throws {
        let webURL = providers.generateWebFallback(for: info)
        let browserChoice = preferences.browserFor(provider: info.platform)
        
        do {
            try await openURLInBrowser(webURL, browser: browserChoice)
        } catch {
            // Copy URL to clipboard as last resort
            await copyToClipboard(url: webURL)
            throw VideoConferenceError.openingFailed("Opened in clipboard instead")
        }
    }
    
    private func openURLInBrowser(_ url: URL, browser: BrowserChoice) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.promptsUserIfNeeded = false
        configuration.activates = true
        
        if let bundleId = browser.bundleIdentifier {
            // Try to open in specific browser
            let apps = NSWorkspace.shared.urlsForApplications(toOpen: url)
            if let appURL = apps.first(where: { Bundle(url: $0)?.bundleIdentifier == bundleId }) {
                try await NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: configuration)
                logger.info("Opened URL in \(browser.displayName): \(url.absoluteString)")
                return
            } else {
                logger.warning("Browser \(browser.displayName) not found, using system default")
            }
        }
        
        // Fallback to system default
        try await NSWorkspace.shared.open(url, configuration: configuration)
        logger.info("Opened URL in system default browser: \(url.absoluteString)")
    }
    
    private func openURL(_ url: URL, promptUser: Bool) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.promptsUserIfNeeded = promptUser
        configuration.activates = true
        
        try await NSWorkspace.shared.open(url, configuration: configuration)
    }
    
    private func copyToClipboard(url: URL) async {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
        logger.info("Copied URL to clipboard: \(url.absoluteString)")
    }
    
    /// Check if system has handler for URL scheme
    private func checkSchemeHandler(for url: URL) async -> Bool {
        guard url.scheme != nil else { return false }
        
        // Use NSWorkspace to check if URL can be opened
        let workspace = NSWorkspace.shared
        return workspace.urlForApplication(toOpen: url) != nil
    }
    
    
}

class SecurityValidator {
    func validateURL(_ url: URL) throws {
        guard let scheme = url.scheme?.lowercased() else {
            throw VideoConferenceError.invalidURL("Missing URL scheme")
        }
        
        // Allow only HTTPS and known safe schemes
        let allowedSchemes = ["https", "zoommtg", "msteams", "googlemeet", "telemost", "discord", "slack", "skype", "tg", "facetime"]
        guard allowedSchemes.contains(scheme) else {
            throw VideoConferenceError.invalidURL("Unsupported URL scheme: \(scheme)")
        }
        
        // Additional validation for known hosts
        if let host = url.host?.lowercased() {
            let trustedHosts = [
                "zoom.us", "zoom.com",
                "teams.microsoft.com", "teams.live.com",
                "meet.google.com",
                "telemost.yandex.ru", "telemost.360.yandex.ru",
                "dion.vc",
                "discord.gg", "discord.com", "canary.discord.com",
                "app.slack.com",
                "webex.com",
                "meet.jit.si",
                "chat.whatsapp.com",
                "t.me",
                "join.skype.com",
                "whereby.com",
                "around.co", "meet.around.co",
                "app.gather.town",
                "lu.ma",
                "facetime.apple.com",
                "gotomeeting.com",
                "bluejeans.com",
                "chime.aws",
                "ringcentral.com",
                "meetings.vonage.com",
                "vk.com"
            ]
            
            let isTrusted = trustedHosts.contains { trustedHost in
                host == trustedHost || host.hasSuffix(".\(trustedHost)")
            }
            
            if !isTrusted && scheme == "https" {
                throw VideoConferenceError.untrustedHost("Host \(host) is not in trusted list")
            }
        }
    }
}

enum VideoConferenceError: Error, LocalizedError {
    case invalidURL(String)
    case untrustedHost(String)
    case openingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL(let message):
            return "Invalid URL: \(message)"
        case .untrustedHost(let message):
            return "Untrusted host: \(message)"
        case .openingFailed(let message):
            return "Failed to open meeting: \(message)"
        }
    }
}
