//
//  BackgroundSyncService.swift
//  TimelyMeet
//
//  
//

import Foundation
import EventKit
import AppKit
import OSLog

@MainActor
class BackgroundSyncService: ObservableObject {
    @Published var lastSyncTime: Date?
    @Published var syncStatus: SyncStatus = .idle
    @Published var syncErrors: [SyncError] = []
    
    private let calendarViewModel: CalendarViewModel
    private let notificationScheduler: NotificationScheduler
    private var backgroundActivity: NSBackgroundActivityScheduler?
    private let logger = Logger(subsystem: "org.romancha.timelymeet", category: "BackgroundSyncService")
    
    // Sync intervals
    private let regularSyncInterval: TimeInterval = 900 // 15 minutes
    private let quickSyncInterval: TimeInterval = 300   // 5 minutes during active periods
    private let errorRetryInterval: TimeInterval = 180  // 3 minutes for retry after error
    
    init(calendarViewModel: CalendarViewModel, notificationScheduler: NotificationScheduler) {
        self.calendarViewModel = calendarViewModel
        self.notificationScheduler = notificationScheduler
        
        setupBackgroundSync()
        startAppLifecycleMonitoring()
    }
    
    private func setupBackgroundSync() {
        backgroundActivity = NSBackgroundActivityScheduler(identifier: "com.meetalert.calendar-sync")
        
        guard let activity = backgroundActivity else { return }
        
        activity.interval = regularSyncInterval
        activity.tolerance = 60 // Allow 1 minute tolerance
        activity.qualityOfService = .utility
        activity.repeats = true
        
        activity.schedule { [weak self] completion in
            Task { @MainActor in
                await self?.performBackgroundSync()
                completion(.finished)
            }
        }
    }
    
    private func startAppLifecycleMonitoring() {
        // Monitor app state changes to optimize sync frequency
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleAppActivation()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleAppDeactivation()
            }
        }
        
        // Monitor system sleep/wake
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleSystemWake()
            }
        }
    }
    
    private func performBackgroundSync() async {
        guard calendarViewModel.authorizationStatus == .fullAccess else {
            let error = SyncError.noCalendarPermission
            syncStatus = .error(error)
            logger.warning("Background Sync: \(error.localizedDescription)")
            return
        }
        
        syncStatus = .syncing
        
        // Store previous events for comparison
        let previousEvents = calendarViewModel.events
        
        // Perform the sync with performance monitoring
        await PerformanceMonitor.shared.measureAsyncBlock("backgroundSync") {
            await calendarViewModel.loadCalendarsAndEvents()
        }
        
        // Check for changes and update notifications if needed
        let hasChanges = detectEventChanges(previous: previousEvents, current: calendarViewModel.events)
        
        if hasChanges {
            logger.info("Event changes detected, rescheduling notifications for \(self.calendarViewModel.events.count) events")
            
            // Reschedule notifications with new event data
            notificationScheduler.handleEventUpdates(calendarViewModel.events)
            
            // Log significant changes
            logEventChanges(previous: previousEvents, current: calendarViewModel.events)
        } else {
            logger.debug("No event changes detected during sync")
        }
        
        lastSyncTime = Date()
        syncStatus = .success
        
        // Clear any previous errors
        syncErrors.removeAll()
        
        // Adjust sync frequency based on upcoming meetings
        adjustSyncFrequency()
    }
    
    private func detectEventChanges(previous: [EKEvent], current: [EKEvent]) -> Bool {
        // Quick check - different counts
        if previous.count != current.count {
            return true
        }
        
        // Create sets of event identifiers and modification dates for comparison
        let previousEventInfo: Set<EventInfo> = Set(previous.compactMap { event in
            guard let id = event.eventIdentifier else { return nil }
            return EventInfo(id: id, lastModified: event.lastModifiedDate ?? Date.distantPast)
        })
        
        let currentEventInfo: Set<EventInfo> = Set(current.compactMap { event in
            guard let id = event.eventIdentifier else { return nil }
            return EventInfo(id: id, lastModified: event.lastModifiedDate ?? Date.distantPast)
        })
        
        return previousEventInfo != currentEventInfo
    }
    
    private func logEventChanges(previous: [EKEvent], current: [EKEvent]) {
        let previousIds = Set(previous.compactMap(\.eventIdentifier))
        let currentIds = Set(current.compactMap(\.eventIdentifier))
        
        let addedEvents = currentIds.subtracting(previousIds)
        let removedEvents = previousIds.subtracting(currentIds)
        
        if !addedEvents.isEmpty {
            logger.info("BackgroundSync: \(addedEvents.count) new events detected")
        }
        
        if !removedEvents.isEmpty {
            logger.info("BackgroundSync: \(removedEvents.count) events removed")
        }
        
        // Check for modified events
        let modifiedCount = current.filter { event in
            guard let id = event.eventIdentifier,
                  let previousEvent = previous.first(where: { $0.eventIdentifier == id }) else {
                return false
            }
            
            let currentModified = event.lastModifiedDate ?? Date.distantPast
            let previousModified = previousEvent.lastModifiedDate ?? Date.distantPast
            
            return currentModified > previousModified
        }.count
        
        if modifiedCount > 0 {
            logger.info("BackgroundSync: \(modifiedCount) events modified")
        }
    }
    
    private func adjustSyncFrequency() {
        guard let activity = backgroundActivity else { return }
        
        let now = Date()
        let upcomingMeetings = calendarViewModel.events.filter { event in
            let timeUntilMeeting = event.startDate.timeIntervalSince(now)
            return timeUntilMeeting > 0 && timeUntilMeeting < 3600 // Next hour
        }
        
        // Use quick sync if there are meetings in the next hour
        let newInterval = upcomingMeetings.isEmpty ? regularSyncInterval : quickSyncInterval
        
        if activity.interval != newInterval {
            activity.interval = newInterval
            logger.info("BackgroundSync: Adjusted sync interval to \(Int(newInterval/60)) minutes")
        }
    }
    
    private func scheduleErrorRetry() {
        // Implement exponential backoff for error retries
        let retryCount = min(syncErrors.count, 5) // Max 5 retries
        let backoffDelay = errorRetryInterval * pow(2.0, Double(retryCount - 1))
        
        Task {
            try? await Task.sleep(for: .seconds(backoffDelay))
            await performBackgroundSync()
        }
    }
    
    private func handleAppActivation() async {
        // Perform immediate sync when app becomes active
        // if it's been more than 5 minutes since last sync
        let shouldSync = lastSyncTime.map { Date().timeIntervalSince($0) > 300 } ?? true
        
        if shouldSync {
            await performBackgroundSync()
        }
    }
    
    private func handleAppDeactivation() async {
        // Switch to more efficient background sync when app goes to background
        backgroundActivity?.interval = regularSyncInterval
    }
    
    private func handleSystemWake() async {
        // Perform immediate sync after system wake
        await performBackgroundSync()
    }
    
    // Manual sync trigger for user-initiated refreshes
    func performManualSync() async {
        await performBackgroundSync()
    }
    
    // Force sync for critical updates
    func performUrgentSync() async {
        backgroundActivity?.interval = quickSyncInterval
        await performBackgroundSync()
    }
    
    func pauseBackgroundSync() {
        backgroundActivity?.invalidate()
        syncStatus = .paused
    }
    
    func resumeBackgroundSync() {
        setupBackgroundSync()
        
        Task {
            await performBackgroundSync()
        }
    }
    
    deinit {
        backgroundActivity?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Supporting Types

enum SyncStatus: Equatable {
    case idle
    case syncing
    case success
    case paused
    case error(SyncError)
    
    static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.syncing, .syncing), (.success, .success), (.paused, .paused):
            return true
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

enum SyncError: Error, LocalizedError, Equatable {
    case noCalendarPermission
    case syncFailed(String)
    case networkError
    case rateLimited
    
    var errorDescription: String? {
        switch self {
        case .noCalendarPermission:
            return "Calendar permission not granted"
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        case .networkError:
            return "Network error during sync"
        case .rateLimited:
            return "Sync rate limited by system"
        }
    }
    
    static func == (lhs: SyncError, rhs: SyncError) -> Bool {
        lhs.localizedDescription == rhs.localizedDescription
    }
}

private struct EventInfo: Hashable {
    let id: String
    let lastModified: Date
}
