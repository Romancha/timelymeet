//
//  NotificationScheduler.swift
//  TimelyMeet
//
//  
//

import Foundation
import EventKit
import UserNotifications
import Dispatch
import OSLog

@MainActor
class NotificationScheduler: ObservableObject {
    @Published var scheduledNotifications: [ScheduledNotification] = []
    
    private let fullscreenService: FullscreenNotificationService
    private let appSettings = AppSettings.shared
    private let logger = Logger(subsystem: "org.romancha.timelymeet", category: "NotificationScheduler")
    
    // Dependencies
    weak var calendarViewModel: CalendarViewModel?
    
    // Track fullscreen notification timers for precise timing
    private var fullscreenTimers: [UUID: DispatchSourceTimer] = [:]
    private var fullscreenTasks: [UUID: Task<Void, Never>] = [:]
    
    init(fullscreenService: FullscreenNotificationService) {
        self.fullscreenService = fullscreenService
    }
    
    func setCalendarViewModel(_ calendarViewModel: CalendarViewModel) {
        logger.debug("setCalendarViewModel called")
        self.calendarViewModel = calendarViewModel
    }
    
    func scheduleNotifications(for events: [EKEvent]) -> [ScheduledNotification] {
        logger.info("Starting to schedule notifications for \(events.count) events")
        
        // Clear existing scheduled notifications
        cancelAllNotifications()
        
        // Get reminder times from app settings
        let reminderTimes = getReminderTimesFromSettings()
        logger.debug("Reminder times: \(reminderTimes)")

        var notifications: [ScheduledNotification] = []
        
        for event in events {
            // Check if this meeting is skipped for today
            let eventIdentifier = event.eventIdentifier
            
            if DataManager.shared.isMeetingSkipped(eventIdentifier: eventIdentifier, meetingDate: event.startDate) {
                logger.debug("Skipping notifications for skipped meeting: \(event.title ?? "Untitled")")
                continue
            }
            
            for seconds in reminderTimes {
                let notificationTime = event.startDate.addingTimeInterval(-Double(seconds))
                
                // Skip if notification time is in the past
                guard notificationTime > Date() else { continue }
                
                let type: NotificationType = determineNotificationType(
                    for: event,
                    secondsBefore: seconds
                )
                
                let notification = ScheduledNotification(
                    id: UUID(),
                    event: event,
                    scheduledTime: notificationTime,
                    type: type,
                    reminderSeconds: seconds
                )
                
                scheduledNotifications.append(notification)
                scheduleNotification(notification)

                notifications.append(notification)
            }
        }

        logger.info("Successfully scheduled \(notifications.count) notifications, total in memory: \(self.scheduledNotifications.count)")
        return notifications
    }
    
    private func getReminderTimesFromSettings() -> [Int] {
        return appSettings.reminderTimes
    }
    
    private func determineNotificationType(for event: EKEvent, secondsBefore: Int) -> NotificationType {
        // Always use fullscreen notifications
        return .fullscreen
    }
    
    private func scheduleNotification(_ notification: ScheduledNotification) {
        switch notification.type {
        case .fullscreen:
            scheduleFullscreenNotificationWithPreciseTiming(notification)
        }
    }
    
    private func scheduleFullscreenNotificationWithPreciseTiming(_ notification: ScheduledNotification) {
        let timeInterval = notification.scheduledTime.timeIntervalSinceNow
        
        // Skip if notification time is in the past
        guard timeInterval > 0 else {
            logger.debug("Skipping notification for past time: \(notification.scheduledTime)")
            return
        }
        
        logger.info("Scheduling fullscreen notification for \(notification.event.title ?? "Untitled") in \(timeInterval) seconds")
        
        // Use high-precision DispatchSourceTimer for critical timing
        let timer = DispatchSource.makeTimerSource(flags: .strict, queue: DispatchQueue.main)
        
        // Schedule timer with nanosecond precision
        let nanoseconds = Int(timeInterval * 1_000_000_000)
        timer.schedule(deadline: .now() + .nanoseconds(nanoseconds), leeway: .nanoseconds(1_000_000)) // 1ms leeway
        
        timer.setEventHandler { [weak self] in
            guard let self = self else {
                return
            }

            // Log timing drift for diagnostics
            let drift = Date().timeIntervalSince(notification.scheduledTime)
            if abs(drift) > 1.0 {
                self.logger.warning("⚠️ Notification timing drift: \(String(format: "%.2f", drift))s for '\(notification.event.title ?? "Untitled")'")
            } else {
                self.logger.info("✅ Notification fired on time (drift: \(String(format: "%.3f", drift))s) for: \(notification.event.title ?? "Untitled")")
            }

            // Extract video info and show notification immediately
            let videoInfo = VideoConferenceManager().extractVideoConferenceInfo(from: notification.event)

            // Show fullscreen notification (already on main queue)
            self.fullscreenService.showFullscreenNotification(for: notification.event, videoInfo: videoInfo)

            // Clean up timer
            self.fullscreenTimers.removeValue(forKey: notification.id)
        }
        
        // Store timer for cancellation BEFORE resume to prevent race conditions
        fullscreenTimers[notification.id] = timer
        
        // Start the timer
        timer.resume()
        
        logger.debug("Timer started successfully for notification: \(notification.id)")
    }
    
    // MARK: - Notification Cancellation
    
    func cancelNotification(withId id: UUID) {
        // Cancel fullscreen timer if exists
        if let timer = fullscreenTimers[id] {
            timer.cancel()
            fullscreenTimers.removeValue(forKey: id)
        }
        
        // Cancel fullscreen task if exists
        if let task = fullscreenTasks[id] {
            task.cancel()
            fullscreenTasks.removeValue(forKey: id)
        }
        
        // Remove from scheduled notifications
        scheduledNotifications.removeAll { $0.id == id }
        
        // Cancel system notification if exists
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id.uuidString])
    }
    
    func cancelAllNotifications() {
        // Cancel all fullscreen timers
        for (_, timer) in fullscreenTimers {
            timer.cancel()
        }
        fullscreenTimers.removeAll()
        
        // Cancel all fullscreen tasks
        for (_, task) in fullscreenTasks {
            task.cancel()
        }
        fullscreenTasks.removeAll()
        
        // Get all notification IDs before clearing
        let notificationIds = scheduledNotifications.map { $0.id.uuidString }
        
        // Clear scheduled notifications
        scheduledNotifications.removeAll()
        
        // Cancel all system notifications
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: notificationIds)
    }
    
    func handleEventUpdates(_ updatedEvents: [EKEvent]) {
        logger.debug("handleEventUpdates() called with \(updatedEvents.count) events")
        // Re-schedule notifications when events change
        scheduleNotifications(for: updatedEvents)
        logger.debug("handleEventUpdates() completed")
    }
    
    func refreshNotificationsAfterSettingsChange() {
        logger.debug("refreshNotificationsAfterSettingsChange() called")
        // Re-schedule all notifications with current settings
        // This method should be called when reminder times change
        
        var eventsToSchedule: [EKEvent] = []
        
        // First try to get events from scheduled notifications
        let currentEvents = Array(Set(scheduledNotifications.map { $0.event }))
        logger.debug("Found \(currentEvents.count) events from \(self.scheduledNotifications.count) scheduled notifications")
        
        if !currentEvents.isEmpty {
            eventsToSchedule = currentEvents
        } else if let calendarVM = calendarViewModel {
            // If no scheduled notifications exist, get events from CalendarViewModel
            eventsToSchedule = calendarVM.events
            logger.info("No scheduled events found, using \(eventsToSchedule.count) events from CalendarViewModel")
        } else {
            logger.warning("No events available for rescheduling (no scheduled notifications and no CalendarViewModel)")
        }
        
        // Re-schedule with updated settings
        if !eventsToSchedule.isEmpty {
            _ = scheduleNotifications(for: eventsToSchedule)
        } else {
            logger.debug("No events to reschedule")
        }
        logger.debug("refreshNotificationsAfterSettingsChange() completed")
    }
    
    /// Reschedules all notifications - used when calendar selection changes
    func rescheduleAllNotifications() async {
        logger.info("Rescheduling all notifications due to settings change")
        refreshNotificationsAfterSettingsChange()
    }
}

// MARK: - Supporting Types

struct ScheduledNotification: Identifiable {
    let id: UUID
    let event: EKEvent
    let scheduledTime: Date
    let type: NotificationType
    let reminderSeconds: Int
}

enum NotificationType: String {
    case fullscreen = "fullscreen"
}
