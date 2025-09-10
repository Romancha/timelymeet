//
//  EnhancedProviders.swift
//  TimelyMeet
//

import Foundation
import AppKit
import OSLog

class EnhancedProviders {
    private let logger = Logger(subsystem: "org.romancha.timelymeet", category: "EnhancedProviders")
    private let urlNormalizer = URLNormalizer()
    
    private let providerPatterns: [(VideoConferencePlatform, [String], String)] = [
        // Platform, Domain patterns, Path regex
        (.zoom, ["zoom.us", "zoomgov.com"], #"^/j/[0-9]+(\?.*)?$"#),
        (.teams, ["teams.microsoft.com", "teams.live.com"], #"^(/l/meetup-join/.*|/meet/[0-9]+.*?)$"#),
        (.meet, ["meet.google.com"], #"^/[a-z0-9-]+(\?.*)?$"#),
        (.telemost, ["telemost.yandex.ru", "telemost.360.yandex.ru"], #"^/j/.*"#),
        (.dion, ["dion.vc"], #"^/.*"#),
        (.discord, ["discord.gg", "discord.com"], #"^/(invite/)?[A-Za-z0-9]+$|^/channels/.*"#),
        (.jitsi, ["meet.jit.si"], #"^/.*"#),
        (.slack, ["app.slack.com"], #"^/huddle/[T][A-Z0-9]+/[C][A-Z0-9]+.*"#),
        (.webex, [], #"\.webex\.com/.*"#),
        (.whatsapp, ["chat.whatsapp.com"], #"^/.*"#),
        (.telegram, ["t.me"], #"^/.*"#),
        (.ringcentral, ["v.ringcentral.com"], #"^/join/[0-9]+.*"#),
        (.skype, ["join.skype.com"], #"^/.*"#),
        (.whereby, ["whereby.com"], #"^/.*"#),
        (.around, ["around.co", "meet.around.co"], #"^/.*"#),
        (.gather, ["app.gather.town"], #"^/app/.*"#),
        (.luma, ["lu.ma"], #"^/join/.*"#),
        (.facetime, ["facetime.apple.com"], #"^/join.*"#),
        (.gotomeeting, [], #"gotomeeting\.com/.*"#),
        (.chime, [], #"chime\.aws/.*"#),
        (.bluejeans, [], #"bluejeans\.com/.*"#),
        (.vonage, ["meetings.vonage.com"], #"^/[0-9]{9}"#),
        (.vkcalls, ["vk.com"], #"^/call/.*"#)
    ]
    
    func detectProvider(from url: URL) -> VideoConferencePlatform? {
        guard let host = url.host?.lowercased() else { return nil }
        let path = url.path
        
        for (platform, domains, pathPattern) in providerPatterns {
            let domainMatches: Bool
            if domains.isEmpty {
                // Use regex for complex domain matching (webex, gotomeeting, etc.)
                domainMatches = host.range(of: pathPattern, options: .regularExpression) != nil
            } else {
                domainMatches = domains.contains { trustedDomain in
                    host == trustedDomain || host.hasSuffix(".\(trustedDomain)")
                }
            }
            
            if domainMatches {
                // Additional path validation for more precise matching
                if !pathPattern.isEmpty && domains.count > 0 {
                    if path.range(of: pathPattern, options: .regularExpression) != nil {
                        return platform
                    }
                } else {
                    return platform
                }
            }
        }
        
        return nil
    }
    
    func generateDeeplink(for info: EnhancedVideoConferenceInfo, strategy: OpeningStrategy) -> URL? {
        // Skip deeplink generation for certain strategies
        if strategy == .alwaysWeb {
            return nil
        }
        
        let config = info.config
        guard config.hasDeeplink, let scheme = config.deeplinkScheme else {
            return nil
        }
        
        let result = generateDeeplinkForPlatform(info, scheme: scheme)
        
        let msg: String = "Generated deeplink for \(info.platform.rawValue) " +
                          "with strategy: \(String(describing: strategy)): " +
                          "\(result?.absoluteString ?? "nil")"

        logger.debug("\(msg, privacy: .public)")
        
        return result
    }
    
    private func generateDeeplinkForPlatform(_ info: EnhancedVideoConferenceInfo, scheme: String) -> URL? {
        switch info.platform {
        case .zoom:
            return generateZoomDeeplink(info, scheme: scheme)
        case .teams:
            return generateTeamsDeeplink(info, scheme: scheme)
        case .telemost:
            return generateTelemostDeeplink(info, scheme: scheme)
        case .discord:
            return generateDiscordDeeplink(info, scheme: scheme)
        case .jitsi:
            return generateJitsiDeeplink(info, scheme: scheme)
        case .slack:
            return generateSlackDeeplink(info, scheme: scheme)
        case .telegram:
            return generateTelegramDeeplink(info, scheme: scheme)
        case .skype:
            return generateSkypeDeeplink(info, scheme: scheme)
        case .vkcalls:
            return generateVkCallsDeepLink(info, scheme: scheme)
        default:
            return nil
        }
    }
    
    private func generateZoomDeeplink(_ info: EnhancedVideoConferenceInfo, scheme: String) -> URL? {
        let url = info.normalizedUrl
        
        // TS Requirement: Personal rooms /my/ should open in web only
        if url.path.starts(with: "/my/") {
            logger.debug("Zoom personal room detected, forcing web fallback")
            return nil
        }
        
        guard let meetingID = extractZoomMeetingID(from: url) else { return nil }
        
        var deeplinkString = "\(scheme)://zoom.us/join?action=join&confno=\(meetingID)"
        
        if let password = info.extractedParameters["pwd"] {
            deeplinkString += "&pwd=\(password)"
        }
        
        return URL(string: deeplinkString)
    }
    
    private func generateTeamsDeeplink(_ info: EnhancedVideoConferenceInfo, scheme: String) -> URL? {
        // TS: Replace https:// with msteams:// keeping rest of URL
        let urlString = info.normalizedUrl.absoluteString
        return URL(string: urlString.replacingOccurrences(of: "https://", with: "\(scheme)://"))
    }
    
    private func generateJitsiDeeplink(_ info: EnhancedVideoConferenceInfo, scheme: String) -> URL? {
        // TS: org.jitsi.meet:// mainly for mobile, check if desktop client installed
        let urlString = info.normalizedUrl.absoluteString
        return URL(string: urlString.replacingOccurrences(of: "https://", with: "\(scheme)://"))
    }
    
    private func generateSlackDeeplink(_ info: EnhancedVideoConferenceInfo, scheme: String) -> URL? {
        // TS: Extract team and ID from huddle URL for proper deeplink format
        let path = info.normalizedUrl.path
        let components = path.components(separatedBy: "/")
        
        guard components.count >= 4,
              components[1] == "huddle",
              let teamID = components.dropFirst(2).first,
              let channelID = components.dropFirst(3).first else {
            return nil
        }
        
        return URL(string: "\(scheme)://join-huddle?team=\(teamID)&id=\(channelID)")
    }
    
    private func generateVkCallsDeepLink(_ info: EnhancedVideoConferenceInfo, scheme: String) -> URL? {
        let url = info.normalizedUrl
        let pathComponents = url.path.components(separatedBy: "/")
        guard pathComponents.count >= 4, pathComponents[1] == "call", pathComponents[2] == "join" else {
            return nil
        }
        let joinLink = pathComponents[3]
        let deeplinkString = "\(scheme)://vk.com/join?joinLink=\(joinLink)"
        
        let resultUrl = URL(string: deeplinkString)
        
        return resultUrl
    }
    
    private func generateSkypeDeeplink(_ info: EnhancedVideoConferenceInfo, scheme: String) -> URL? {
        let urlString = info.normalizedUrl.absoluteString
        return URL(string: urlString.replacingOccurrences(of: "https://", with: "\(scheme)://"))
    }
    
    private func generateTelemostDeeplink(_ info: EnhancedVideoConferenceInfo, scheme: String) -> URL? {
        let yandexDeepLink = "\(scheme)://" + info.normalizedUrl.absoluteString
        return URL(string: yandexDeepLink)
    }
    
    private func generateDiscordDeeplink(_ info: EnhancedVideoConferenceInfo, scheme: String) -> URL? {
        // Discord deeplink transformation
        let urlString = info.normalizedUrl.absoluteString
        return URL(string: urlString.replacingOccurrences(of: "https://", with: "\(scheme)://"))
    }
    
    private func generateTelegramDeeplink(_ info: EnhancedVideoConferenceInfo, scheme: String) -> URL? {
        // Telegram deeplink transformation
        let urlString = info.normalizedUrl.absoluteString
        return URL(string: urlString.replacingOccurrences(of: "https://", with: "\(scheme)://"))
    }
    
    private func extractZoomMeetingID(from url: URL) -> String? {
        // Extract from path like /j/1234567890
        if url.path.starts(with: "/j/") {
            let meetingID = String(url.path.dropFirst(3))
            return meetingID.components(separatedBy: "?")[0]
        }
        
        // Try query parameters
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems,
           let confno = queryItems.first(where: { $0.name == "confno" })?.value {
            return confno
        }
        
        return nil
    }
    
    func shouldForceWebFallback(for info: EnhancedVideoConferenceInfo) -> Bool {
        let config = info.config
        
        // Check special handling rules
        if config.specialHandling.contains("personal_rooms_web_only") &&
           info.platform == .zoom &&
           info.normalizedUrl.path.starts(with: "/my/") {
            return true
        }
        
        if config.specialHandling.contains("meetings_web_only") &&
           info.platform == .webex {
            return true
        }
        
        if config.specialHandling.contains("universal_links_only") &&
           info.platform == .meet {
            return true
        }
        
        return false
    }
    
    func generateWebFallback(for info: EnhancedVideoConferenceInfo) -> URL {
        // TS: For RingCentral, use web deeplink format
        if info.platform == .ringcentral {
            let meetingID = extractRingCentralMeetingID(from: info.normalizedUrl)
            if !meetingID.isEmpty {
                return URL(string: "https://v.ringcentral.com/join/\(meetingID)") ?? info.normalizedUrl
            }
        }
        
        return info.normalizedUrl
    }
    
    private func extractRingCentralMeetingID(from url: URL) -> String {
        // Extract meeting ID from various RingCentral URL formats
        let pathComponents = url.path.components(separatedBy: "/")
        if let joinIndex = pathComponents.firstIndex(of: "join"),
           joinIndex + 1 < pathComponents.count {
            return pathComponents[joinIndex + 1]
        }
        return ""
    }
}
