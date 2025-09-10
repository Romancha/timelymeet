//
//  DataManager.swift
//  TimelyMeet
//
//  
//

import Foundation
import CoreData
import OSLog

/// Manages Core Data persistence for the TimelyMeet application
/// Follows Apple's recommended patterns for Core Data in SwiftUI apps
class DataManager: ObservableObject {
    static let shared = DataManager()
    private let logger = Logger(subsystem: "org.romancha.timelymeet", category: "DataManager")
    
    /// The persistent container for the application's Core Data stack
    /// Using lazy initialization as recommended by Apple
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "DataModel")
        
        // Configure for better performance and concurrent access
        container.loadPersistentStores { _, error in
            if let error = error {
                // Use proper error handling instead of fatalError in production
                self.logger.error("Core Data failed to load store: \(error.localizedDescription)")
                // Consider implementing fallback or recovery logic here
            }
        }
        
        // Enable automatic merging from parent context
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        // Configure for better memory management
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    /// The main managed object context for UI operations
    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    /// Creates a background context for heavy operations
    /// Follows Apple's pattern for background processing
    func backgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    private init() {}
    
    /// Saves the view context if it has changes
    /// Follows Apple's error handling patterns
    func save() {
        save(context: viewContext)
    }
    
    /// Saves the specified context if it has changes
    /// - Parameter context: The context to save
    private func save(context: NSManagedObjectContext) {
        guard context.hasChanges else { return }
        
        do {
            try context.save()
        } catch {
            // Follow Apple's pattern of detailed error logging
            logger.error("Failed to save context: \(error.localizedDescription)")
            if let detailedErrors = error as? CocoaError {
                logger.error("Detailed Core Data error: \(detailedErrors)")
            }
        }
    }
    
    /// Performs a background task with proper context handling
    /// Follows Apple's recommended pattern for background operations
    func performBackgroundTask(_ task: @escaping (NSManagedObjectContext) -> Void) {
        let context = backgroundContext()
        context.perform {
            task(context)
            self.save(context: context)
        }
    }
    
    // MARK: - Calendar Settings
    
    func getCalendarSetting(for calendarIdentifier: String) -> CalendarSetting? {
        let request: NSFetchRequest<CalendarSetting> = CalendarSetting.fetchRequest()
        request.predicate = NSPredicate(format: "calendarIdentifier == %@", calendarIdentifier)
        request.fetchLimit = 1
        
        do {
            return try viewContext.fetch(request).first
        } catch {
            logger.error("Failed to fetch calendar setting: \(error.localizedDescription)")
            return nil
        }
    }
    
    func createOrUpdateCalendarSetting(calendarIdentifier: String, title: String, isEnabled: Bool) {
        let setting = getCalendarSetting(for: calendarIdentifier) ?? CalendarSetting(context: viewContext)
        setting.calendarIdentifier = calendarIdentifier
        setting.title = title
        setting.isEnabled = isEnabled
        setting.lastModified = Date()
        
        save()
    }
    
    func getAllCalendarSettings() -> [CalendarSetting] {
        let request: NSFetchRequest<CalendarSetting> = CalendarSetting.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CalendarSetting.title, ascending: true)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            logger.error("Failed to fetch calendar settings: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Notification Settings
    
    func getNotificationSetting(for eventIdentifier: String) -> NotificationSetting? {
        let request: NSFetchRequest<NotificationSetting> = NotificationSetting.fetchRequest()
        request.predicate = NSPredicate(format: "eventIdentifier == %@", eventIdentifier)
        request.fetchLimit = 1
        
        do {
            return try viewContext.fetch(request).first
        } catch {
            logger.error("Failed to fetch notification setting: \(error.localizedDescription)")
            return nil
        }
    }
    
    func createOrUpdateNotificationSetting(
        eventIdentifier: String,
        isEnabled: Bool = true,
        reminderMinutes: Int32 = 5,
        soundEnabled: Bool = true
    ) {
        let setting = getNotificationSetting(for: eventIdentifier) ?? NotificationSetting(context: viewContext)
        setting.eventIdentifier = eventIdentifier
        setting.isEnabled = isEnabled
        setting.reminderMinutes = reminderMinutes
        setting.soundEnabled = soundEnabled
        setting.lastModified = Date()
        
        save()
    }
    
    func getAllNotificationSettings() -> [NotificationSetting] {
        let request: NSFetchRequest<NotificationSetting> = NotificationSetting.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \NotificationSetting.lastModified, ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            logger.error("Failed to fetch notification settings: \(error.localizedDescription)")
            return []
        }
    }
    
    func deleteOldNotificationSettings(olderThan date: Date) {
        let request: NSFetchRequest<NotificationSetting> = NotificationSetting.fetchRequest()
        request.predicate = NSPredicate(format: "lastModified < %@", date as NSDate)
        
        do {
            let oldSettings = try viewContext.fetch(request)
            oldSettings.forEach { viewContext.delete($0) }
            save()
        } catch {
            logger.error("Failed to delete old notification settings: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Skipped Meetings
    
    func skipMeeting(eventIdentifier: String, eventTitle: String?, meetingDate: Date, calendarIdentifier: String?) {
        let skippedMeeting = SkippedMeeting(context: viewContext)
        skippedMeeting.eventIdentifier = eventIdentifier
        skippedMeeting.eventTitle = eventTitle
        skippedMeeting.meetingDate = meetingDate
        skippedMeeting.skippedAt = Date()
        skippedMeeting.calendarIdentifier = calendarIdentifier
        
        save()
    }
    
    func isMeetingSkipped(eventIdentifier: String?, meetingDate: Date) -> Bool {
        if eventIdentifier == nil {
            return false
        }
        
        let request: NSFetchRequest<SkippedMeeting> = SkippedMeeting.fetchRequest()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: meetingDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? meetingDate
        
        request.predicate = NSPredicate(format: "eventIdentifier == %@ AND meetingDate >= %@ AND meetingDate < %@", 
                                      eventIdentifier!,
                                      startOfDay as NSDate,
                                      endOfDay as NSDate)
        request.fetchLimit = 1
        
        do {
            let results = try viewContext.fetch(request)
            return !results.isEmpty
        } catch {
            logger.error("Failed to check if meeting is skipped: \(error.localizedDescription)")
            return false
        }
    }
    
    func unskipMeeting(eventIdentifier: String, meetingDate: Date) {
        let request: NSFetchRequest<SkippedMeeting> = SkippedMeeting.fetchRequest()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: meetingDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? meetingDate
        
        request.predicate = NSPredicate(format: "eventIdentifier == %@ AND meetingDate >= %@ AND meetingDate < %@", 
                                      eventIdentifier, 
                                      startOfDay as NSDate, 
                                      endOfDay as NSDate)
        
        do {
            let skippedMeetings = try viewContext.fetch(request)
            skippedMeetings.forEach { viewContext.delete($0) }
            save()
        } catch {
            logger.error("Failed to unskip meeting: \(error.localizedDescription)")
        }
    }
    
    func getAllSkippedMeetings() -> [SkippedMeeting] {
        let request: NSFetchRequest<SkippedMeeting> = SkippedMeeting.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SkippedMeeting.skippedAt, ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            logger.error("Failed to fetch skipped meetings: \(error.localizedDescription)")
            return []
        }
    }
    
    func deleteOldSkippedMeetings(olderThan date: Date) {
        let request: NSFetchRequest<SkippedMeeting> = SkippedMeeting.fetchRequest()
        request.predicate = NSPredicate(format: "meetingDate < %@", date as NSDate)
        
        do {
            let oldSkippedMeetings = try viewContext.fetch(request)
            oldSkippedMeetings.forEach { viewContext.delete($0) }
            save()
        } catch {
            logger.error("Failed to delete old skipped meetings: \(error.localizedDescription)")
        }
    }
}
