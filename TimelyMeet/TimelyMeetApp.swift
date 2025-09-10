//
//  TimelyMeetApp.swift
//  TimelyMeet
//
//  Created by Roman Makarskiy on 24.08.2025.
//

import SwiftUI
import CoreData
import Foundation

@main
struct TimelyMeetApp: App {
    @StateObject private var app = AppModel()
    
    var body: some Scene {
        MenuBarExtra {
            AppRoot(app: app) { MenuBarView() }
        } label: {
            AppRoot(app: app) { MenuBarLabelView() }
        }
        .menuBarExtraStyle(.window)
        
        .defaultSize(width: 800, height: 600)
        .windowResizability(.contentSize)
        .commandsRemoved()
        
        Settings {
            AppRoot(app: app) { EnhancedSettingsView() }
        }
    }
}

struct AppRoot<Content: View>: View {
    @ObservedObject var app: AppModel
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        content()
            .environmentObject(app)
            .environmentObject(app.calendarViewModel)
            .environmentObject(app.menuBarService)
            .environmentObject(app.fullscreenService)
            .environmentObject(app.analyticsService)
            .environmentObject(app.customSoundService)
            .environmentObject(app.themeService)
            .environmentObject(app.developerModeService)
            .environmentObject(app.notificationScheduler)
            .environmentObject(app.backgroundSync)
            .environmentObject(app.localizationManager)
            .environmentObject(app.videoConferenceManager)
            .environment(\.managedObjectContext, app.dataManager.viewContext)
            .environment(\.locale, app.localizationManager.currentLocale)
    }
}
// MARK: - App Model
@MainActor
class AppModel: ObservableObject {
    @Published var isInitialized = false
    
    // Core services
    let dataManager = DataManager.shared
    let calendarViewModel = CalendarViewModel()
    let menuBarService = MenuBarService()
    
    // Additional services
    let analyticsService = MeetingAnalyticsService()
    let customSoundService = CustomSoundService()
    let themeService = NotificationThemeService()
    let developerModeService = DeveloperModeService.shared
    let localizationManager = LocalizationManager.shared
    let videoConferenceManager = VideoConferenceManager()
    
    // Dependent services that need theme service
    lazy var fullscreenService = FullscreenNotificationService(themeService: themeService)
    
    // Dependent services
    lazy var notificationScheduler = NotificationScheduler(
        fullscreenService: fullscreenService
    )
    
    lazy var backgroundSync = BackgroundSyncService(
        calendarViewModel: calendarViewModel,
        notificationScheduler: notificationScheduler
    )
    
    func initialize() async {
        // Prevent App Nap and automatic termination for reliable notifications
        configureBackgroundExecution()
        
        // Track app launch for analytics
        analyticsService.trackAppLaunch()
        
        // Load user preferences
        customSoundService.loadSelectedSound()
        
        // Check calendar access on startup
        await checkCalendarPermissions()
        
        // Connect menu bar service to calendar view model
        menuBarService.setCalendarViewModel(calendarViewModel)
        menuBarService.updateMenuBarTitle()
        
        // Set up calendar view model dependencies for proper notification handling
        calendarViewModel.setDependencies(
            notificationScheduler: notificationScheduler,
            menuBarService: menuBarService
        )
        
        // Set up notification scheduler dependency for settings changes
        notificationScheduler.setCalendarViewModel(calendarViewModel)
        
        // Set up calendar event change monitoring
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.backgroundSync.performUrgentSync()
            }
        }
        
        // Configure NotificationScheduler for developer mode
        developerModeService.configureNotificationScheduler(notificationScheduler)
        
        // Clean up old skipped meetings (older than 7 days)
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        dataManager.deleteOldSkippedMeetings(olderThan: sevenDaysAgo)
        
        // Initialize background sync
        await backgroundSync.performManualSync()
        
        // Force menu bar update after full initialization
        menuBarService.updateMenuBarTitle()
        
        // Mark as initialized to trigger UI updates
        isInitialized = true
    }
    
    /// Checks calendar permissions on app startup and requests access if needed
    private func checkCalendarPermissions() async {
        calendarViewModel.checkAuthorizationStatus()
        
        switch calendarViewModel.authorizationStatus {
        case .notDetermined:
            // Request access automatically on first launch
            await calendarViewModel.requestCalendarAccess()
        case .fullAccess:
            // Load data immediately if we have full access
            await calendarViewModel.loadCalendarsAndEvents()
        default:
            // For other states (denied, restricted, writeOnly), don't automatically request
            // The user will see the notification in MenuBarView and can manually enable
            break
        }
    }
    
    private func configureBackgroundExecution() {
        // Prevent sudden termination to ensure notifications fire
        ProcessInfo.processInfo.disableSuddenTermination()
        
        // Disable automatic termination with reason
        ProcessInfo.processInfo.disableAutomaticTermination("Meeting notifications active")
        
        // Prevent App Nap for consistent timer execution
        // Note: ProcessInfo.processInfo doesn't have beginActivity in SwiftUI apps
        // The Info.plist settings handle this instead
    }
}
