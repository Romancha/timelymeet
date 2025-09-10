//
//  MeetingAnalyticsService.swift
//  TimelyMeet
//
//  
//

import Foundation
import EventKit
import AppKit

@MainActor
class MeetingAnalyticsService: ObservableObject {
    @Published var analytics: MeetingAnalytics = MeetingAnalytics()
    @Published var recentActivity: [MeetingActivity] = []
    
    private let dataManager = DataManager.shared
    private let maxRecentActivities = 50
    
    init() {
        loadAnalytics()
    }
    
    // MARK: - Tracking Methods
    
    func trackNotificationShown(for event: EKEvent, type: NotificationType, minutesBefore: Int) {
        let activity = MeetingActivity(
            id: UUID(),
            eventId: event.eventIdentifier ?? "",
            eventTitle: event.title ?? "Unknown Event",
            action: .notificationShown,
            timestamp: Date(),
            platform: extractPlatform(from: event),
            metadata: [
                "type": type == .fullscreen ? "fullscreen" : "system",
                "minutesBefore": "\(minutesBefore)"
            ]
        )
        
        addActivity(activity)
        
        analytics.totalNotificationsShown += 1
        if type == .fullscreen {
            analytics.fullscreenNotificationsShown += 1
        }
        
        saveAnalytics()
    }
    
    func trackNotificationDismissed(for event: EKEvent, method: DismissMethod) {
        let activity = MeetingActivity(
            id: UUID(),
            eventId: event.eventIdentifier ?? "",
            eventTitle: event.title ?? "Unknown Event",
            action: .notificationDismissed,
            timestamp: Date(),
            platform: extractPlatform(from: event),
            metadata: ["method": method.rawValue]
        )
        
        addActivity(activity)
        
        analytics.totalNotificationsDismissed += 1
        analytics.dismissMethodCounts[method, default: 0] += 1
        
        saveAnalytics()
    }
    
    func trackMeetingJoinAttempt(for event: EKEvent, platform: VideoConferencePlatform, url: URL) {
        let activity = MeetingActivity(
            id: UUID(),
            eventId: event.eventIdentifier ?? "",
            eventTitle: event.title ?? "Unknown Event",
            action: .joinAttempted,
            timestamp: Date(),
            platform: platform,
            metadata: [
                "url": url.absoluteString,
                "host": url.host ?? "unknown"
            ]
        )
        
        addActivity(activity)
        
        analytics.totalJoinAttempts += 1
        analytics.platformJoinCounts[platform, default: 0] += 1
        
        saveAnalytics()
        
        // Start tracking for success/failure
        trackJoinSuccess(for: event, platform: platform, after: 5.0) // Check after 5 seconds
    }
    
    func trackMeetingJoinSuccess(for event: EKEvent, platform: VideoConferencePlatform) {
        let activity = MeetingActivity(
            id: UUID(),
            eventId: event.eventIdentifier ?? "",
            eventTitle: event.title ?? "Unknown Event",
            action: .joinSuccessful,
            timestamp: Date(),
            platform: platform,
            metadata: [:]
        )
        
        addActivity(activity)
        
        analytics.successfulJoins += 1
        analytics.platformSuccessfulJoins[platform, default: 0] += 1
        
        saveAnalytics()
    }
    
    func trackMeetingJoinFailure(for event: EKEvent, platform: VideoConferencePlatform, error: String) {
        let activity = MeetingActivity(
            id: UUID(),
            eventId: event.eventIdentifier ?? "",
            eventTitle: event.title ?? "Unknown Event",
            action: .joinFailed,
            timestamp: Date(),
            platform: platform,
            metadata: ["error": error]
        )
        
        addActivity(activity)
        
        analytics.failedJoins += 1
        analytics.platformFailedJoins[platform, default: 0] += 1
        
        saveAnalytics()
    }
    
    func trackAppLaunch() {
        analytics.appLaunches += 1
        analytics.lastLaunchDate = Date()
        saveAnalytics()
    }
    
    // MARK: - Analytics Calculations
    
    func getJoinSuccessRate() -> Double {
        guard analytics.totalJoinAttempts > 0 else { return 0 }
        return Double(analytics.successfulJoins) / Double(analytics.totalJoinAttempts)
    }
    
    func getJoinSuccessRate(for platform: VideoConferencePlatform) -> Double {
        let attempts = analytics.platformJoinCounts[platform, default: 0]
        guard attempts > 0 else { return 0 }
        let successes = analytics.platformSuccessfulJoins[platform, default: 0]
        return Double(successes) / Double(attempts)
    }
    
    func getNotificationEngagementRate() -> Double {
        let totalInteractions = analytics.successfulJoins + analytics.totalNotificationsDismissed
        guard analytics.totalNotificationsShown > 0 else { return 0 }
        return Double(totalInteractions) / Double(analytics.totalNotificationsShown)
    }
    
    func getFullscreenEffectiveness() -> Double {
        guard analytics.fullscreenNotificationsShown > 0 else { return 0 }
        
        // Count successful joins from fullscreen notifications
        let fullscreenJoins = recentActivity.filter { activity in
            activity.action == .joinSuccessful &&
            recentActivity.contains { prev in
                prev.eventId == activity.eventId &&
                prev.action == .notificationShown &&
                prev.metadata["type"] == "fullscreen" &&
                prev.timestamp < activity.timestamp
            }
        }.count
        
        return Double(fullscreenJoins) / Double(analytics.fullscreenNotificationsShown)
    }
    
    func getMostReliablePlatforms() -> [(VideoConferencePlatform, Double)] {
        let platforms = VideoConferencePlatform.allCases.filter { $0 != .unknown }
        
        return platforms.compactMap { platform in
            let successRate = getJoinSuccessRate(for: platform)
            let attempts = analytics.platformJoinCounts[platform, default: 0]
            
            // Only include platforms with at least 3 attempts for statistical relevance
            guard attempts >= 3 else { return nil }
            
            return (platform, successRate)
        }.sorted { $0.1 > $1.1 } // Sort by success rate descending
    }
    
    func getPeakNotificationTimes() -> [Int] {
        // Analyze notification timing to find most effective reminder times
        let notificationActivities = recentActivity.filter { $0.action == .notificationShown }
        let timingCounts = Dictionary(grouping: notificationActivities) { activity in
            Int(activity.metadata["minutesBefore"] ?? "5") ?? 5
        }.mapValues(\.count)
        
        return timingCounts.sorted { $0.value > $1.value }.map(\.key)
    }
    
    // MARK: - Private Methods
    
    private func addActivity(_ activity: MeetingActivity) {
        recentActivity.insert(activity, at: 0)
        
        // Keep only the most recent activities
        if recentActivity.count > maxRecentActivities {
            recentActivity = Array(recentActivity.prefix(maxRecentActivities))
        }
    }
    
    private func extractPlatform(from event: EKEvent) -> VideoConferencePlatform {
        return VideoConferenceManager().extractVideoConferenceInfo(from: event)?.platform ?? .unknown
    }
    
    private func trackJoinSuccess(for event: EKEvent, platform: VideoConferencePlatform, after delay: TimeInterval) {
        Task {
            try? await Task.sleep(for: .seconds(delay))
            
            // Heuristic: Check if the platform app is now the active application
            let activeApp = NSWorkspace.shared.frontmostApplication
            let isSuccessful = checkIfMeetingAppIsActive(for: platform, activeApp: activeApp)
            
            if isSuccessful {
                trackMeetingJoinSuccess(for: event, platform: platform)
            } else {
                // Try again after a longer delay
                if delay < 15.0 {
                    trackJoinSuccess(for: event, platform: platform, after: delay + 5.0)
                } else {
                    // Assume failure if app hasn't become active after 15 seconds
                    trackMeetingJoinFailure(for: event, platform: platform, error: "App did not become active")
                }
            }
        }
    }
    
    private func checkIfMeetingAppIsActive(for platform: VideoConferencePlatform, activeApp: NSRunningApplication?) -> Bool {
        guard let bundleId = activeApp?.bundleIdentifier else { return false }
        
        let platformBundleIds: [VideoConferencePlatform: [String]] = [
            .zoom: ["us.zoom.xos", "ZoomPhone"],
            .teams: ["com.microsoft.teams", "com.microsoft.teams2"],
            .meet: ["com.google.Chrome", "com.apple.Safari"],
            .telemost: ["com.google.Chrome", "com.apple.Safari"],
            .dion: ["com.google.Chrome", "com.apple.Safari"],
            .discord: ["com.hnc.Discord", "com.discord.Discord"],
            .slack: ["com.tinyspeck.slackmacgap"],
            .webex: ["Cisco-Systems.Spark", "com.cisco.webex.meetings"],
            .jitsi: ["org.jitsi.jitsi-meet"],
            .whatsapp: ["net.whatsapp.WhatsApp", "com.google.Chrome", "com.apple.Safari"],
            .telegram: ["ru.keepcoder.Telegram"],
            .skype: ["com.skype.skype"],
            .whereby: ["com.google.Chrome", "com.apple.Safari"],
            .around: ["com.google.Chrome", "com.apple.Safari"],
            .gather: ["com.google.Chrome", "com.apple.Safari"],
            .luma: ["com.google.Chrome", "com.apple.Safari"],
            .facetime: ["com.apple.FaceTime"],
            .gotomeeting: ["com.citrixonline.GoToMeeting"],
            .bluejeans: ["com.bluejeans.BlueJeansApp"],
            .chime: ["com.amazon.AmazonChime"],
            .ringcentral: ["com.ringcentral.RingCentral"],
            .vonage: ["com.vonage.VonageBusinessCommunications"],
            .vkcalls: ["com.vk.vkcalls", "com.google.Chrome", "com.apple.Safari"]
        ]
        
        let expectedBundleIds = platformBundleIds[platform] ?? []
        return expectedBundleIds.contains { expectedId in
            bundleId.contains(expectedId) || bundleId.lowercased().contains(expectedId.lowercased())
        }
    }
    
    private func loadAnalytics() {
        // Load analytics from UserDefaults or Core Data
        if let data = UserDefaults.standard.data(forKey: "MeetingAnalytics"),
           let decoded = try? JSONDecoder().decode(MeetingAnalytics.self, from: data) {
            analytics = decoded
        }
        
        if let activityData = UserDefaults.standard.data(forKey: "RecentMeetingActivity"),
           let decodedActivity = try? JSONDecoder().decode([MeetingActivity].self, from: activityData) {
            recentActivity = decodedActivity
        }
    }
    
    private func saveAnalytics() {
        if let encoded = try? JSONEncoder().encode(analytics) {
            UserDefaults.standard.set(encoded, forKey: "MeetingAnalytics")
        }
        
        if let encodedActivity = try? JSONEncoder().encode(recentActivity) {
            UserDefaults.standard.set(encodedActivity, forKey: "RecentMeetingActivity")
        }
    }
    
    // MARK: - Public Reporting Methods
    
    func generateWeeklyReport() -> WeeklyAnalyticsReport {
        let oneWeekAgo = Date().addingTimeInterval(-604800) // 7 days
        let weeklyActivity = recentActivity.filter { $0.timestamp >= oneWeekAgo }
        
        return WeeklyAnalyticsReport(
            totalNotifications: weeklyActivity.filter { $0.action == .notificationShown }.count,
            successfulJoins: weeklyActivity.filter { $0.action == .joinSuccessful }.count,
            failedJoins: weeklyActivity.filter { $0.action == .joinFailed }.count,
            dismissedNotifications: weeklyActivity.filter { $0.action == .notificationDismissed }.count,
            averageResponseTime: calculateAverageResponseTime(from: weeklyActivity),
            topPlatforms: getTopPlatforms(from: weeklyActivity)
        )
    }
    
    private func calculateAverageResponseTime(from activities: [MeetingActivity]) -> TimeInterval {
        let pairs = activities.compactMap { activity -> TimeInterval? in
            guard activity.action == .joinAttempted else { return nil }
            
            // Find the corresponding notification shown event
            if let notificationEvent = activities.first(where: { prev in
                prev.eventId == activity.eventId &&
                prev.action == .notificationShown &&
                prev.timestamp < activity.timestamp
            }) {
                return activity.timestamp.timeIntervalSince(notificationEvent.timestamp)
            }
            return nil
        }
        
        guard !pairs.isEmpty else { return 0 }
        return pairs.reduce(0, +) / Double(pairs.count)
    }
    
    private func getTopPlatforms(from activities: [MeetingActivity]) -> [(VideoConferencePlatform, Int)] {
        let platformCounts = Dictionary(grouping: activities.filter { $0.action == .joinSuccessful }) { $0.platform }
            .mapValues(\.count)
        
        return platformCounts.sorted { $0.value > $1.value }
    }
}

// MARK: - Data Models

struct MeetingAnalytics: Codable {
    var totalNotificationsShown: Int = 0
    var fullscreenNotificationsShown: Int = 0
    var totalNotificationsDismissed: Int = 0
    var totalJoinAttempts: Int = 0
    var successfulJoins: Int = 0
    var failedJoins: Int = 0
    var appLaunches: Int = 0
    var lastLaunchDate: Date?
    
    private var _platformJoinCounts: [String: Int] = [:]
    private var _platformSuccessfulJoins: [String: Int] = [:]
    private var _platformFailedJoins: [String: Int] = [:]
    private var _dismissMethodCounts: [String: Int] = [:]
    
    var platformJoinCounts: [VideoConferencePlatform: Int] {
        get {
            Dictionary(uniqueKeysWithValues: _platformJoinCounts.compactMap { key, value in
                guard let platform = VideoConferencePlatform(rawValue: key) else { return nil }
                return (platform, value)
            })
        }
        set {
            _platformJoinCounts = Dictionary(uniqueKeysWithValues: newValue.map { ($0.rawValue, $1) })
        }
    }
    
    var platformSuccessfulJoins: [VideoConferencePlatform: Int] {
        get {
            Dictionary(uniqueKeysWithValues: _platformSuccessfulJoins.compactMap { key, value in
                guard let platform = VideoConferencePlatform(rawValue: key) else { return nil }
                return (platform, value)
            })
        }
        set {
            _platformSuccessfulJoins = Dictionary(uniqueKeysWithValues: newValue.map { ($0.rawValue, $1) })
        }
    }
    
    var platformFailedJoins: [VideoConferencePlatform: Int] {
        get {
            Dictionary(uniqueKeysWithValues: _platformFailedJoins.compactMap { key, value in
                guard let platform = VideoConferencePlatform(rawValue: key) else { return nil }
                return (platform, value)
            })
        }
        set {
            _platformFailedJoins = Dictionary(uniqueKeysWithValues: newValue.map { ($0.rawValue, $1) })
        }
    }
    
    var dismissMethodCounts: [DismissMethod: Int] {
        get {
            Dictionary(uniqueKeysWithValues: _dismissMethodCounts.compactMap { key, value in
                guard let method = DismissMethod(rawValue: key) else { return nil }
                return (method, value)
            })
        }
        set {
            _dismissMethodCounts = Dictionary(uniqueKeysWithValues: newValue.map { ($0.rawValue, $1) })
        }
    }
}

struct MeetingActivity: Codable, Identifiable {
    let id: UUID
    let eventId: String
    let eventTitle: String
    let action: MeetingAction
    let timestamp: Date
    let platform: VideoConferencePlatform
    let metadata: [String: String]
}

enum MeetingAction: String, Codable, CaseIterable {
    case notificationShown = "notification_shown"
    case notificationDismissed = "notification_dismissed"
    case joinAttempted = "join_attempted"
    case joinSuccessful = "join_successful"
    case joinFailed = "join_failed"
}

enum DismissMethod: String, Codable, CaseIterable {
    case userDismiss = "user_dismiss"
    case autoTimeout = "auto_timeout"
    case snoozed = "snoozed"
    case joinedMeeting = "joined_meeting"
}

struct WeeklyAnalyticsReport {
    let totalNotifications: Int
    let successfulJoins: Int
    let failedJoins: Int
    let dismissedNotifications: Int
    let averageResponseTime: TimeInterval
    let topPlatforms: [(VideoConferencePlatform, Int)]
}
