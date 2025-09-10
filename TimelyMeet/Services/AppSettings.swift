//
//  AppSettings.swift
//  TimelyMeet
//
//  Centralized application settings service that provides default values
//  and encapsulates all user preferences management
//

import Foundation
import OSLog

/// Centralized settings service that provides default values and manages user preferences
/// Following single responsibility principle and proper encapsulation
@MainActor
class AppSettings: ObservableObject {
    
    // MARK: - Singleton Instance
    
    static let shared = AppSettings()
    private let logger = Logger(subsystem: "org.romancha.timelymeet", category: "AppSettings")
    
    private init() {
        // Private initializer to ensure singleton usage
    }
    
    // MARK: - Notification Settings
    
    struct NotificationDefaults {
        // All available reminder time options
        static let availableReminderTimes = [0, 30, 60, 300, 600, 900] // meeting time, 30s, 1m, 5m, 10m, 15m
        
        // Default selected reminder times (only 1 minute)
        static let defaultReminderTimes = [60] // 1 minute
        static let defaultReminderTimesString = defaultReminderTimes.map(String.init).joined(separator: ",")
        static let reminderTimesKey = "reminderTimesString"
    }
    
    var reminderTimes: [Int] {
        let reminderTimesString = UserDefaults.standard.string(forKey: NotificationDefaults.reminderTimesKey) ?? NotificationDefaults.defaultReminderTimesString
        return reminderTimesString.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }
    
    func setReminderTimes(_ times: [Int]) {
        let timesString = times.map(String.init).joined(separator: ",")
        UserDefaults.standard.set(timesString, forKey: NotificationDefaults.reminderTimesKey)
    }
    
    // MARK: - Menu Bar Settings
    
    struct MenuBarDefaults {
        static let displayThreshold: Double = 24.0
        static let showTime: Bool = true
        static let showEventTitle: Bool = true
        static let autoWidth: Bool = true
        static let widthPt: Double = 120.0
        static let minBudget: CGFloat = 30.0
        static let maxBudjet: CGFloat = 400.0
    }
    
    var menuBarDisplayThreshold: Double {
        get {
            let value = UserDefaults.standard.double(forKey: "menuBarDisplayThreshold")
            return value == 0 ? MenuBarDefaults.displayThreshold : value
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "menuBarDisplayThreshold")
            objectWillChange.send()
        }
    }
    
    var menuBarShowTime: Bool {
        get {
            UserDefaults.standard.object(forKey: "menuBarShowTime") as? Bool ?? MenuBarDefaults.showTime
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "menuBarShowTime")
            objectWillChange.send()
        }
    }
    
    var menuBarShowEventTitle: Bool {
        get {
            UserDefaults.standard.object(forKey: "menuBarShowEventTitle") as? Bool ?? MenuBarDefaults.showEventTitle
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "menuBarShowEventTitle")
            objectWillChange.send()
        }
    }
    
    
    var menuBarMinBudget: CGFloat = MenuBarDefaults.minBudget
    var menuBarMaxBudget: CGFloat = MenuBarDefaults.maxBudjet
    
    var statusBarAutoWidth: Bool {
        get {
            UserDefaults.standard.object(forKey: "statusBarAutoWidth") as? Bool ?? MenuBarDefaults.autoWidth
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "statusBarAutoWidth")
            objectWillChange.send()
        }
    }
    
    var statusBarWidthPt: Double {
        get {
            let value = UserDefaults.standard.double(forKey: "statusBarWidthPt")
            return value == 0 ? MenuBarDefaults.widthPt : value
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "statusBarWidthPt")
            objectWillChange.send()
        }
    }
    
    // MARK: - Calendar Settings
    
    struct CalendarDefaults {
        static let selectedCalendarsKey = "selectedCalendarIds"
    }
    
    var selectedCalendarIds: Set<String> {
        get {
            guard let data = UserDefaults.standard.data(forKey: CalendarDefaults.selectedCalendarsKey),
                  let ids = try? JSONDecoder().decode(Set<String>.self, from: data) else {
                return Set<String>()
            }
            return ids
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                UserDefaults.standard.set(data, forKey: CalendarDefaults.selectedCalendarsKey)
                objectWillChange.send()
            } catch {
                logger.error("Failed to save selected calendars: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Sound Settings
    
    struct SoundDefaults {
        static let notificationSoundKey = "selectedNotificationSound"
        static let notificationThemeKey = "selectedNotificationTheme"
        static let defaultSoundId = "default"
        static let defaultTheme = "system"
    }
    
    var selectedNotificationSound: String {
        get {
            UserDefaults.standard.string(forKey: SoundDefaults.notificationSoundKey) ?? SoundDefaults.defaultSoundId
        }
        set {
            UserDefaults.standard.set(newValue, forKey: SoundDefaults.notificationSoundKey)
            objectWillChange.send()
        }
    }
    
    var selectedNotificationTheme: String {
        get {
            UserDefaults.standard.string(forKey: SoundDefaults.notificationThemeKey) ?? SoundDefaults.defaultTheme
        }
        set {
            UserDefaults.standard.set(newValue, forKey: SoundDefaults.notificationThemeKey)
            objectWillChange.send()
        }
    }
    
    // MARK: - Localization Settings
    
    struct LocalizationDefaults {
        static let selectedLocaleKey = "selectedLocale"
    }
    
    var selectedLocale: String? {
        get {
            UserDefaults.standard.string(forKey: LocalizationDefaults.selectedLocaleKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: LocalizationDefaults.selectedLocaleKey)
            objectWillChange.send()
        }
    }
    
    // MARK: - Analytics Settings
    
    struct AnalyticsDefaults {
        static let analyticsDataKey = "MeetingAnalytics"
        static let recentActivityKey = "RecentMeetingActivity"
    }
    
    // MARK: - Video Conference Settings
    
    struct VideoConferenceDefaults {
        static let providerStrategiesKey = "videoconference_provider_strategies"
        static let providerBrowsersKey = "videoconference_provider_browsers"
        
        // Get recommended settings for specific provider
        static func recommendedStrategy(for provider: VideoConferencePlatform) -> OpeningStrategy {
            return ProviderConfig.configs[provider]?.recommendedStrategy ?? .systemDefault
        }
        
        static func recommendedBrowser(for provider: VideoConferencePlatform) -> BrowserChoice {
            return ProviderConfig.configs[provider]?.recommendedBrowser ?? .system
        }
    }
    
    
    
    // MARK: - Developer Settings
    
    struct DeveloperDefaults {
        static let developerModeKey = "developerMode"
        static let developerMode: Bool = false
    }
    
    var isDeveloperModeEnabled: Bool {
        get {
            UserDefaults.standard.object(forKey: DeveloperDefaults.developerModeKey) as? Bool ?? DeveloperDefaults.developerMode
        }
        set {
            UserDefaults.standard.set(newValue, forKey: DeveloperDefaults.developerModeKey)
            objectWillChange.send()
        }
    }
    
    // MARK: - Time Constants
    
    struct TimeConstants {
        static let oneMinute: Int = 60
        static let fiveMinutes: Int = 300
        static let tenMinutes: Int = 600
        static let fifteenMinutes: Int = 900
        static let thirtySeconds: Int = 30
    }
    
    // MARK: - UI Constants
    
    struct UIConstants {
        static let cornerRadius: CGFloat = 8
        static let defaultSpacing: CGFloat = 12
        static let smallSpacing: CGFloat = 8
        static let largeSpacing: CGFloat = 16
    }
    
    // MARK: - Reset Methods
    
    func resetToDefaults() {
        menuBarDisplayThreshold = MenuBarDefaults.displayThreshold
        menuBarShowTime = MenuBarDefaults.showTime
        menuBarShowEventTitle = MenuBarDefaults.showEventTitle
        statusBarAutoWidth = MenuBarDefaults.autoWidth
        statusBarWidthPt = MenuBarDefaults.widthPt
        setReminderTimes(NotificationDefaults.defaultReminderTimes)
        selectedNotificationSound = SoundDefaults.defaultSoundId
        selectedNotificationTheme = SoundDefaults.defaultTheme
        isDeveloperModeEnabled = DeveloperDefaults.developerMode
        
        // Video conference settings are now provider-specific only
        // Reset provider-specific settings by clearing user defaults
        UserDefaults.standard.removeObject(forKey: VideoConferenceDefaults.providerStrategiesKey)
        UserDefaults.standard.removeObject(forKey: VideoConferenceDefaults.providerBrowsersKey)
    }
}
