//
//  EnhancedSettingsView.swift
//  TimelyMeet
//
//  
//

import SwiftUI
import EventKit

struct EnhancedSettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var calendarViewModel: CalendarViewModel
    @EnvironmentObject private var fullscreenService: FullscreenNotificationService
    @EnvironmentObject private var analyticsService: MeetingAnalyticsService
    @EnvironmentObject private var customSoundService: CustomSoundService
    @EnvironmentObject private var themeService: NotificationThemeService
    @EnvironmentObject private var notificationScheduler: NotificationScheduler
    @EnvironmentObject private var backgroundSync: BackgroundSyncService
    @EnvironmentObject private var developerModeService: DeveloperModeService
    @EnvironmentObject private var localizationManager: LocalizationManager
    
    @State private var selectedTab: SettingsTab = .notifications
    
    var body: some View {
        NavigationSplitView {
            // Settings sidebar
            SettingsSidebar(selectedTab: $selectedTab)
                .frame(minWidth: 200)
        } detail: {
            // Settings detail view
            SettingsDetailView(selectedTab: selectedTab)
                .environmentObject(appModel)
                .frame(minWidth: 500, minHeight: 600)
        }
        .navigationTitle("settings_title".localized())
        .onAppear {
            // Reset click count when settings open
            developerModeService.resetAboutClickCount()
        }
    }
}

struct SettingsSidebar: View {
    @Binding var selectedTab: SettingsTab
    @EnvironmentObject private var developerModeService: DeveloperModeService
    
    private var visibleTabs: [SettingsTab] {
        SettingsTab.allCases.filter { tab in
            if tab == .developer {
                return developerModeService.isDevModeEnabled
            }
            return true
        }
    }
    
    var body: some View {
        List(visibleTabs, id: \.self, selection: $selectedTab) { tab in
            Label(tab.title, systemImage: tab.iconName)
                .tag(tab)
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(200)
    }
}

struct SettingsDetailView: View {
    let selectedTab: SettingsTab
    @EnvironmentObject private var localizationManager: LocalizationManager
    @EnvironmentObject private var appModel: AppModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                switch selectedTab {
                case .notifications:
                    NotificationSettingsView()
//                case .themes:
//                    ThemeSettingsView()
                case .menuBar:
                    MenuBarSettingsView()
                        .environmentObject(appModel)
                case .calendar:
                    CalendarSettingsView()
                case .videoConference:
                    VideoConferenceSettingsView()
                case .language:
                    LanguageSettingsView()
//                case .analytics:
//                    AnalyticsView()
                case .about:
                    AboutView()
                case .whatsNew:
                    WhatsNewView()
                case .developer:
                    DeveloperSettingsView()
                        .environmentObject(appModel.videoConferenceManager)
                }
            }
            .padding(24)
        }
    }
}

// MARK: - Individual Settings Views

enum SettingsTab: String, CaseIterable {
    case notifications = "notifications"
    //case themes = "themes"
    case menuBar = "menuBar"
    case calendar = "calendar"
    case videoConference = "videoConference"
    case language = "language"
//    case analytics = "analytics"
    case about = "about"
    case whatsNew = "whatsNew"
    case developer = "developer"
    
    var title: String {
        switch self {
        case .notifications: return "settings_notifications".localized()
                    //case .themes: return "settings_themes".localized()
        case .menuBar: return "settings_menubar".localized()
        case .calendar: return "settings_calendar".localized()
        case .videoConference: return "video_conferences".localized()
        case .language: return "settings_language".localized()
            //        case .analytics: return "settings_analytics".localized()
        case .about: return "settings_about".localized()
        case .whatsNew: return "settings_whats_new".localized()
        case .developer: return "settings_developer".localized()
        }
    }
    
    var iconName: String {
        switch self {
        case .notifications: return "bell"
        //case .themes: return "paintbrush"
        case .menuBar: return "menubar.rectangle"
        case .calendar: return "calendar"
        case .videoConference: return "video.circle"
        case .language: return "globe"
//        case .analytics: return "chart.line.uptrend.xyaxis"
        case .about: return "info.circle"
        case .whatsNew: return "star.circle"
        case .developer: return "hammer.fill"
        }
    }
}

#Preview {
    let themeService = NotificationThemeService()
    let fullscreenService = FullscreenNotificationService(themeService: themeService)
    let notificationScheduler = NotificationScheduler(
        fullscreenService: fullscreenService
    )
    
    return EnhancedSettingsView()
        .environmentObject(CalendarViewModel())
        .environmentObject(fullscreenService)
        .environmentObject(MeetingAnalyticsService())
        .environmentObject(CustomSoundService())
        .environmentObject(themeService)
        .environmentObject(notificationScheduler)
        .environmentObject(BackgroundSyncService(calendarViewModel: CalendarViewModel(), notificationScheduler: notificationScheduler))
}
