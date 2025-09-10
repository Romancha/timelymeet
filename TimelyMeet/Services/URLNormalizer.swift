//
//  URLNormalizer.swift
//  TimelyMeet
//

import Foundation
import OSLog

/// Handles URL normalization and Safe Links processing per Technical Specification
class URLNormalizer {
    private let logger = Logger(subsystem: "org.romancha.timelymeet", category: "URLNormalizer")
    
    /// Normalizes URL by removing Safe Links wrappers and cleaning tracking parameters
    func normalize(_ url: URL) throws -> URL {
        var currentURL = url
        
        // Remove Safe Links wrappers (Office 365, Gmail, etc.)
        currentURL = try removeSafeLinksWrappers(from: currentURL)
        
        // Clean tracking parameters
        currentURL = cleanTrackingParameters(from: currentURL)
        
        // Ensure proper percent encoding
        currentURL = ensureProperEncoding(currentURL)
        
        logger.debug("Normalized URL from \(url.absoluteString) to \(currentURL.absoluteString)")
        return currentURL
    }
    
    private func removeSafeLinksWrappers(from url: URL) throws -> URL {
        guard let host = url.host?.lowercased() else { return url }
        
        // Microsoft Safe Links (safelinks.protection.outlook.com)
        if host.contains("safelinks.protection.outlook.com") ||
           host.contains("protect.office.com") ||
           host.contains("nam.safelinks.protection.outlook.com") {
            return try extractFromMicrosoftSafeLinks(url)
        }
        
        // Gmail Safe Browsing (google.com/url)
        if host == "google.com" && url.path.starts(with: "/url") {
            return try extractFromGoogleSafeLinks(url)
        }
        
        // ATP Safe Links (various Microsoft domains)
        if host.contains("atp.microsoft.com") || host.contains("advprotection") {
            return try extractFromATPSafeLinks(url)
        }
        
        return url
    }
    
    private func extractFromMicrosoftSafeLinks(_ url: URL) throws -> URL {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            throw VideoConferenceError.invalidURL("Cannot parse Safe Links URL")
        }
        
        // Look for 'url' parameter
        if let urlParam = queryItems.first(where: { $0.name == "url" }),
           let urlValue = urlParam.value,
           let decodedURL = URL(string: urlValue) {
            return decodedURL
        }
        
        // Look for 'data' parameter (newer format)
        if let dataParam = queryItems.first(where: { $0.name == "data" }),
           let dataValue = dataParam.value,
           let decodedData = Data(base64Encoded: dataValue),
           let jsonString = String(data: decodedData, encoding: .utf8) {
            // Try to parse JSON for URL
            if let jsonData = jsonString.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let originalURL = json["url"] as? String,
               let url = URL(string: originalURL) {
                return url
            }
        }
        
        throw VideoConferenceError.invalidURL("Cannot extract URL from Safe Links wrapper")
    }
    
    private func extractFromGoogleSafeLinks(_ url: URL) throws -> URL {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            throw VideoConferenceError.invalidURL("Cannot parse Google Safe Links URL")
        }
        
        // Look for 'url' or 'q' parameter
        for paramName in ["url", "q"] {
            if let urlParam = queryItems.first(where: { $0.name == paramName }),
               let urlValue = urlParam.value?.removingPercentEncoding,
               let decodedURL = URL(string: urlValue) {
                return decodedURL
            }
        }
        
        throw VideoConferenceError.invalidURL("Cannot extract URL from Google Safe Links")
    }
    
    private func extractFromATPSafeLinks(_ url: URL) throws -> URL {
        // Similar logic to Microsoft Safe Links but for ATP-specific formats
        return try extractFromMicrosoftSafeLinks(url)
    }
    
    private func cleanTrackingParameters(from url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        
        let trackingParameters = [
            // Google Analytics & UTM
            "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
            "gclid", "gclsrc", "dclid",
            
            // Facebook
            "fbclid", "fb_source", "fb_ref",
            
            // Twitter
            "twsrc", "ref_src", "ref_url",
            
            // General tracking
            "ref", "source", "campaign", "medium",
            
            // Email tracking
            "_hsenc", "_hsmi", "hsCtaTracking",
            
            // Microsoft
            "ocid", "cvid"
        ]
        
        if let queryItems = components.queryItems {
            components.queryItems = queryItems.filter { item in
                !trackingParameters.contains(item.name.lowercased())
            }
            
            // Remove empty query string
            if components.queryItems?.isEmpty == true {
                components.queryItems = nil
            }
        }
        
        return components.url ?? url
    }
    
    private func ensureProperEncoding(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        
        // Ensure query items are properly encoded
        if let queryItems = components.queryItems {
            components.queryItems = queryItems.compactMap { item in
                URLQueryItem(
                    name: item.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? item.name,
                    value: item.value?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? item.value
                )
            }
        }
        
        return components.url ?? url
    }
}
