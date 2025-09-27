//
//  SettingsWindowManager.swift
//  TimelyMeet
//
//  
//

import Foundation
import SwiftUI
import AppKit

// Custom NSWindowController that properly manages delegate lifecycle
@MainActor
class SettingsWindowController: NSWindowController {
    private let windowDelegate = SettingsWindowDelegate()
    private let onClose: () -> Void
    
    init(
        appModel: AppModel,
        calendarViewModel: CalendarViewModel,
        menuBarService: MenuBarService,
        fullscreenService: FullscreenNotificationService,
        analyticsService: MeetingAnalyticsService,
        customSoundService: CustomSoundService,
        themeService: NotificationThemeService,
        developerModeService: DeveloperModeService,
        notificationScheduler: NotificationScheduler,
        backgroundSync: BackgroundSyncService,
        localizationManager: LocalizationManager,
        initialTab: SettingsTab = .notifications,
        onClose: @escaping () -> Void
    ) {
        self.onClose = onClose
        
        // Create window with proper configuration
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 800),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: true
        )
        
        super.init(window: window)
        
        window.title = "TimelyMeet Settings"
        window.isReleasedWhenClosed = false
        
        // Check calendar permissions when settings are opened
        Task {
            await checkCalendarPermissionsOnSettingsOpen(calendarViewModel: calendarViewModel)
        }
        
        // Create hosting view with proper bridge options
        let settingsView = EnhancedSettingsView(initialTab: initialTab)
            .environmentObject(appModel)
            .environmentObject(calendarViewModel)
            .environmentObject(menuBarService)
            .environmentObject(fullscreenService)
            .environmentObject(analyticsService)
            .environmentObject(customSoundService)
            .environmentObject(themeService)
            .environmentObject(developerModeService)
            .environmentObject(notificationScheduler)
            .environmentObject(backgroundSync)
            .environmentObject(localizationManager)
        
        let hostingView = NSHostingView(rootView: settingsView)
        
        // Configure hosting view with proper scene bridging options
        if #available(macOS 14.0, *) {
            hostingView.sceneBridgingOptions = [.title, .toolbars]
        }
        
        window.contentView = hostingView
        
        // Set up delegate - strong reference is maintained by this controller
        windowDelegate.onClose = { [weak self] in
            self?.onClose()
        }
        window.delegate = windowDelegate
        
        // Center window
        window.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Checks calendar permissions when settings are opened
    private func checkCalendarPermissionsOnSettingsOpen(calendarViewModel: CalendarViewModel) async {
        await MainActor.run {
            calendarViewModel.checkAuthorizationStatus()
        }
        
        // If we have access, refresh the data to ensure it's current
        if calendarViewModel.authorizationStatus == .fullAccess {
            await calendarViewModel.loadCalendarsAndEvents()
        }
    }
}

// Window delegate with strong reference lifecycle management
class SettingsWindowDelegate: NSObject, NSWindowDelegate {
    var onClose: (() -> Void)?
    
    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}

@MainActor
class SettingsWindowManager: ObservableObject {
    static let shared = SettingsWindowManager()
    
    private var settingsWindowController: SettingsWindowController?
    
    private init() {}
    
    func openSettings(
        appModel: AppModel? = nil,
        calendarViewModel: CalendarViewModel? = nil,
        menuBarService: MenuBarService? = nil,
        fullscreenService: FullscreenNotificationService? = nil,
        analyticsService: MeetingAnalyticsService? = nil,
        customSoundService: CustomSoundService? = nil,
        themeService: NotificationThemeService? = nil,
        developerModeService: DeveloperModeService? = nil,
        notificationScheduler: NotificationScheduler? = nil,
        backgroundSync: BackgroundSyncService? = nil,
        localizationManager: LocalizationManager = LocalizationManager.shared,
        initialTab: SettingsTab = .notifications
    ) {
        // If settings already open, bring to front following Apple HIG guidelines
        if let existingController = settingsWindowController,
           let window = existingController.window,
           window.isVisible {
            // Properly bring window to front according to macOS best practices
            NSApplication.shared.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            return
        }
        
        // Clean up existing controller
        settingsWindowController?.close()
        settingsWindowController = nil
        
        // Use provided services or create new ones
        let appModel = appModel ?? AppModel()
        let calendarVM = calendarViewModel ?? CalendarViewModel()
        let menuBarSvc = menuBarService ?? MenuBarService()
        let themeSvc = themeService ?? NotificationThemeService()
        let fullscreenSvc = fullscreenService ?? FullscreenNotificationService(themeService: themeSvc)
        let analyticsSvc = analyticsService ?? MeetingAnalyticsService()
        let soundSvc = customSoundService ?? CustomSoundService()
        let localizationMgr = LocalizationManager.shared
        let devSvc = developerModeService ?? DeveloperModeService.shared
        let notificationSched = notificationScheduler ?? NotificationScheduler(
            fullscreenService: fullscreenSvc
        )
        let backgroundSvc = backgroundSync ?? BackgroundSyncService(
            calendarViewModel: calendarVM,
            notificationScheduler: notificationSched
        )
        
        // Create new window controller - this manages the delegate lifecycle properly
        let windowController = SettingsWindowController(
            appModel: appModel,
            calendarViewModel: calendarVM,
            menuBarService: menuBarSvc,
            fullscreenService: fullscreenSvc,
            analyticsService: analyticsSvc,
            customSoundService: soundSvc,
            themeService: themeSvc,
            developerModeService: devSvc,
            notificationScheduler: notificationSched,
            backgroundSync: backgroundSvc,
            localizationManager: localizationMgr,
            initialTab: initialTab,
            onClose: { [weak self] in
                self?.settingsWindowController = nil
            }
        )
        
        self.settingsWindowController = windowController
        
        // Show window following Apple HIG for Settings windows
        windowController.showWindow(nil)
        
        // Ensure proper window focus according to macOS guidelines
        if let window = windowController.window {
            NSApplication.shared.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }
    
    // Compatibility methods
    func openBasicSettings() {
        openSettings()
    }

    func openAdvancedSettings() {
        openSettings()
    }

    func openAbout() {
        openSettings(initialTab: .about)
    }
}
