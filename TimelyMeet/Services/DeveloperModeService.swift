//
//  DeveloperModeService.swift
//  TimelyMeet
//
//  
//

import Foundation
import EventKit
import UserNotifications
import OSLog
import AppKit

@MainActor
class DeveloperModeService: ObservableObject {
    static let shared = DeveloperModeService()
    
    @Published var isDevModeEnabled = false
    @Published var aboutClickCount = 0
    
    private let requiredClickCount = 10
    @Published var isPerformanceMonitoringEnabled = false
    @Published var testNotificationSeconds: Int = 5
    @Published var lastTestNotificationTime: Date?
    @Published var testNotificationHistory: [TestNotification] = []
    @Published var scheduledWorkflowNotifications: [ScheduledWorkflowNotification] = []
    @Published var testMeetingURL: String = "https://telemost.360.yandex.ru/j/000"
    
    private let logger = Logger(subsystem: "org.romancha.timelymeet", category: "DeveloperMode")
    private let fullscreenService: FullscreenNotificationService
    private var notificationScheduler: NotificationScheduler?
    private let userDefaults = UserDefaults.standard
    
    // Dev mode settings keys
    private let devModeEnabledKey = "devModeEnabled"
    private let performanceMonitoringEnabledKey = "performanceMonitoringEnabled"
    private let testNotificationSecondsKey = "testNotificationSeconds"
    private let testMeetingURLKey = "testMeetingURL"
    
    private init() {
        let themeService = NotificationThemeService()
        self.fullscreenService = FullscreenNotificationService(themeService: themeService)
        loadSettings()
    }
    
    /// Configure NotificationScheduler for full workflow emulation
    func configureNotificationScheduler(_ scheduler: NotificationScheduler) {
        self.notificationScheduler = scheduler
        logger.info("NotificationScheduler configured for developer mode")
    }
    
    // MARK: - Settings Management
    
    private func loadSettings() {
        isDevModeEnabled = userDefaults.bool(forKey: devModeEnabledKey)
        isPerformanceMonitoringEnabled = userDefaults.bool(forKey: performanceMonitoringEnabledKey)
        testNotificationSeconds = max(1, userDefaults.integer(forKey: testNotificationSecondsKey))
        if testNotificationSeconds == 0 {
            testNotificationSeconds = 5 // Default value
        }
        
        let savedURL = userDefaults.string(forKey: testMeetingURLKey)
        if let savedURL = savedURL, !savedURL.isEmpty {
            testMeetingURL = savedURL
        }
    }
    
    private func saveSettings() {
        userDefaults.set(isDevModeEnabled, forKey: devModeEnabledKey)
        userDefaults.set(isPerformanceMonitoringEnabled, forKey: performanceMonitoringEnabledKey)
        userDefaults.set(testNotificationSeconds, forKey: testNotificationSecondsKey)
        userDefaults.set(testMeetingURL, forKey: testMeetingURLKey)
    }
    
    func toggleDevMode() {
        isDevModeEnabled.toggle()
        saveSettings()
        logger.info("Developer mode \(self.isDevModeEnabled ? "enabled" : "disabled")")
        
        // Toggle performance monitoring based on dev mode and monitoring setting
        Task { @MainActor in
            PerformanceMonitor.shared.toggleMonitoringBasedOnDevMode()
        }
    }
    
    func togglePerformanceMonitoring() {
        isPerformanceMonitoringEnabled.toggle()
        saveSettings()
        logger.info("Performance monitoring \(self.isPerformanceMonitoringEnabled ? "enabled" : "disabled")")
        
        // Update performance monitor state
        Task { @MainActor in
            PerformanceMonitor.shared.toggleMonitoringBasedOnDevMode()
        }
    }
    
    func updateTestNotificationSeconds(_ seconds: Int) {
        testNotificationSeconds = max(1, min(300, seconds)) // 1 second to 5 minutes max
        saveSettings()
        logger.debug("Test notification timing updated to \(self.testNotificationSeconds) seconds")
    }
    
    func updateTestMeetingURL(_ url: String) {
        testMeetingURL = url
        saveSettings()
        logger.debug("Test meeting URL updated to \(url)")
    }
    
    func cancelAllTestNotifications() {
        let center = UNUserNotificationCenter.current()
        
        center.getPendingNotificationRequests { [weak self] requests in
            let testNotificationIds = requests.compactMap { request -> String? in
                if let isTest = request.content.userInfo["isTestNotification"] as? Bool, isTest {
                    return request.identifier
                }
                return nil
            }
            
            if !testNotificationIds.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: testNotificationIds)
                DispatchQueue.main.async {
                    self?.logger.info("Cancelled \(testNotificationIds.count) pending test notifications")
                }
            }
        }
    }
    
    // MARK: - Mock Event Creation
    
    func createMockEvent(title: String = "Test Meeting", minutesFromNow: Int) -> EKEvent {
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        
        event.title = title
        event.startDate = Date().addingTimeInterval(TimeInterval(minutesFromNow * 60))
        event.endDate = event.startDate.addingTimeInterval(1800) // 30 minutes duration
        event.notes = "This is a test meeting created by TimelyMeet Developer Mode.\n\nJoin Zoom Meeting:\nhttps://zoom.us/j/1234567890"
        event.location = "Developer Mode Test"
        
        // Note: We can't actually create EKParticipant instances directly in sandbox
        // but we can simulate the meeting characteristics through title and notes
        
        return event
    }
    
    // MARK: - Developer Analytics
    
    func getTestingAnalytics() -> TestingAnalytics {
        let totalTests = testNotificationHistory.count
        let recentTests = testNotificationHistory.filter { 
            $0.scheduledAt.timeIntervalSinceNow > -3600 // Last hour
        }.count
        
        let averageSeconds = testNotificationHistory.isEmpty ? 0 : 
            testNotificationHistory.reduce(0) { $0 + $1.seconds } / testNotificationHistory.count
        
        return TestingAnalytics(
            totalTestNotifications: totalTests,
            recentTestNotifications: recentTests,
            averageTestSeconds: averageSeconds,
            lastTestTime: lastTestNotificationTime,
            isDevModeActive: isDevModeEnabled
        )
    }
    
    func clearTestHistory() {
        testNotificationHistory.removeAll()
        lastTestNotificationTime = nil
        logger.info("Test notification history cleared")
    }
    
    func testFullscreenNotification() {
        guard isDevModeEnabled else {
            logger.warning("Attempted to test fullscreen notification without dev mode enabled")
            return
        }
        
        logger.info("Testing fullscreen notification immediately for \(self.testMeetingURL)")
        fullscreenService.testFullscreenNotification(for: testMeetingURL)
        lastTestNotificationTime = Date()
    }
    
    
    /// Emulates the complete real-world workflow: calendar scanning -> smart scheduling -> notifications
    func emulateFullWorkflow(eventStartDate: Date) async -> Bool {
        guard isDevModeEnabled else {
            logger.warning("Attempted to emulate full workflow without dev mode enabled")
            return false
        }
        
        guard let notificationScheduler = notificationScheduler else {
            logger.error("NotificationScheduler not configured! Call configureNotificationScheduler() first")
            return false
        }
        
        logger.info("Mock Meeting...")
        
        // Step 1: Create mock calendar events (emulating CalendarViewModel.loadCalendarsAndEvents)
        let mockEvents = createMockCalendarEvent(eventStartDate: eventStartDate)
        
        // Step 2: Process events through NotificationScheduler
        let notifications = notificationScheduler.scheduleNotifications(for: mockEvents)
        
        // Clear previous workflow notifications and update UI
        await MainActor.run {
            self.scheduledWorkflowNotifications.removeAll()
        }
        
        for notification in notifications {
            let timeRemaining = notification.scheduledTime.timeIntervalSinceNow
            logger.info("  - \(notification.event.title ?? "Untitled") (\(notification.type.rawValue)) in \(Int(timeRemaining))s")
            
            // Track this notification for UI display
            let workflowNotification = ScheduledWorkflowNotification(
                id: notification.id,
                eventTitle: notification.event.title ?? "Untitled Event",
                scheduledTime: notification.scheduledTime,
                notificationType: notification.type,
                reminderSeconds: notification.reminderSeconds,
                eventStartTime: notification.event.startDate
            )
            
            await MainActor.run {
                self.scheduledWorkflowNotifications.append(workflowNotification)
            }

            // Track in test history
            let testNotification = TestNotification(
                scheduledAt: notification.scheduledTime,
                deliveryTime: notification.scheduledTime,
                seconds: notification.reminderSeconds,
                mockEventTitle: notification.event.title
            )
            testNotificationHistory.insert(testNotification, at: 0)
            if testNotificationHistory.count > 20 {
                testNotificationHistory = Array(testNotificationHistory.prefix(20))
            }
        }
        
        lastTestNotificationTime = Date()
        logger.info("✅ Full workflow emulation completed successfully")
        
        return true
    }
    
    /// Creates a single mock calendar event for testing
    private func createMockCalendarEvent(eventStartDate: Date) -> [EKEvent] {
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        
        // Create single test meeting
        event.title = "Core team meeting"
        event.startDate = eventStartDate
        event.endDate = eventStartDate.addingTimeInterval(1800) // 30 minutes duration
        
        // Add video conference info using configurable URL
        event.notes = """
        Test meeting created by TimelyMeet Developer Mode.
        
        Meeting agenda:
        - Test notification workflow
        - Verify fullscreen alerts
        - Check system notifications
        
        Join Meeting:
        \(testMeetingURL)
        
        Meeting ID: 5031636879
        """
        
        // Create mock calendar
        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = "Working Calendar"
        calendar.cgColor = NSColor.systemTeal.cgColor
        event.calendar = calendar
        
        return [event]
    }
    
    // MARK: - Scheduled Notifications Management
    
    func cancelWorkflowNotification(_ notificationId: UUID) {
        guard let notificationScheduler = notificationScheduler else {
            logger.warning("Cannot cancel notification - NotificationScheduler not configured")
            return
        }
        
        // Use NotificationScheduler's cancellation method
        notificationScheduler.cancelNotification(withId: notificationId)
        
        // Remove from our tracking list and trigger UI update
        DispatchQueue.main.async {
            self.scheduledWorkflowNotifications.removeAll { $0.id == notificationId }
        }
        
        logger.info("Cancelled workflow notification: \(notificationId)")
    }
    
    func cancelAllWorkflowNotifications() {
        guard let notificationScheduler = notificationScheduler else {
            logger.warning("Cannot cancel notifications - NotificationScheduler not configured")
            return
        }
        
        let notificationCount = scheduledWorkflowNotifications.count
        
        // Use NotificationScheduler's cancellation method
        notificationScheduler.cancelAllNotifications()
        
        // Clear from our tracking and trigger UI update
        DispatchQueue.main.async {
            self.scheduledWorkflowNotifications.removeAll()
        }
        
        logger.info("Cancelled all \(notificationCount) workflow notifications")
    }
    
    // MARK: - Secret Developer Mode
    
    func handleAboutTabClick() {
        aboutClickCount += 1
        
        if aboutClickCount >= requiredClickCount {
            enableSecretDevMode()
        }
        
        // Reset counter after 30 seconds of inactivity
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            if self.aboutClickCount < self.requiredClickCount {
                self.aboutClickCount = 0
            }
        }
    }
    
    func resetAboutClickCount() {
        aboutClickCount = 0
    }
    
    private func enableSecretDevMode() {
        logger.info("Secret developer mode activation detected! (\(self.aboutClickCount) clicks on About tab)")
        isDevModeEnabled = true
        saveSettings()
        resetAboutClickCount()
        
        // Show subtle confirmation to user
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
        
        // Post notification for UI to react
        NotificationCenter.default.post(name: .devModeToggled, object: self)
    }
}

// MARK: - Supporting Types

struct TestNotification: Identifiable, Codable {
    let id: UUID
    let scheduledAt: Date
    let deliveryTime: Date
    let seconds: Int
    let mockEventTitle: String?
    
    init(scheduledAt: Date, deliveryTime: Date, seconds: Int, mockEventTitle: String? = nil) {
        self.id = UUID()
        self.scheduledAt = scheduledAt
        self.deliveryTime = deliveryTime
        self.seconds = seconds
        self.mockEventTitle = mockEventTitle
    }
    
    var isForMockEvent: Bool {
        return mockEventTitle != nil
    }
    
    var displayTitle: String {
        return mockEventTitle ?? "Test Notification"
    }
}

struct TestingAnalytics {
    let totalTestNotifications: Int
    let recentTestNotifications: Int
    let averageTestSeconds: Int
    let lastTestTime: Date?
    let isDevModeActive: Bool
}

struct ScheduledWorkflowNotification: Identifiable {
    let id: UUID
    let eventTitle: String
    let scheduledTime: Date
    let notificationType: NotificationType
    let reminderSeconds: Int
    let eventStartTime: Date
    
    var timeUntilNotification: TimeInterval {
        return scheduledTime.timeIntervalSinceNow
    }
    
    var timeUntilEvent: TimeInterval {
        return eventStartTime.timeIntervalSinceNow
    }
    
    var formattedScheduledTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: scheduledTime)
    }
    
    var formattedEventTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: eventStartTime)
    }
    
    var typeDisplayName: String {
        switch notificationType {
        case .fullscreen:
            return "Fullscreen"
        }
    }
    
    var typeColor: NSColor {
        switch notificationType {
        case .fullscreen:
            return .systemOrange
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let testNotificationScheduled = Notification.Name("testNotificationScheduled")
    static let devModeToggled = Notification.Name("devModeToggled")
}
