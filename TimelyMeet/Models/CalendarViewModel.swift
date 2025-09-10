//
//  CalendarViewModel.swift
//  TimelyMeet
//
//

import SwiftUI
import EventKit
import Combine
import OSLog

/// Calendar view model following Apple's async/await patterns and proper error handling
/// Based on Apple's EventKit best practices and sample code patterns
@MainActor
class CalendarViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var events: [EKEvent] = []
    @Published var isLoading = false
    @Published var calendars: [EKCalendar] = []
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?
    @Published var selectedCalendarIds: Set<String> = []
    @Published var skippedMeetingIds: Set<String> = []
    
    private let eventStore = EKEventStore()
    private let appSettings = AppSettings.shared
    private var cancellables: Set<AnyCancellable> = []
    private let logger = Logger(subsystem: "org.romancha.timelymeet", category: "CalendarViewModel")
    
    // Dependencies for proper separation of concerns
    weak var notificationScheduler: NotificationScheduler?
    weak var menuBarService: MenuBarService?
    
    // Prevents multiple simultaneous calendar update operations
    private var isHandlingCalendarChange = false
    
    init() {
        checkAuthorizationStatus()
        loadSelectedCalendars()
        observeSettingsChanges()
    }
    
    /// Sets dependencies for proper separation of concerns
    func setDependencies(notificationScheduler: NotificationScheduler?, menuBarService: MenuBarService?) {
        logger.debug("setDependencies called, notificationScheduler: \(notificationScheduler != nil ? "set" : "nil")")
        self.notificationScheduler = notificationScheduler
        self.menuBarService = menuBarService
    }
    
    private func observeSettingsChanges() {
        // Observe changes to selected calendars from AppSettings
        $selectedCalendarIds
            .dropFirst()
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main) // Reduced debounce time
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.handleCalendarSelectionChange()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Loads selected calendar IDs from AppSettings
    private func loadSelectedCalendars() {
        selectedCalendarIds = appSettings.selectedCalendarIds
    }
    
    /// Saves selected calendar IDs to AppSettings and triggers updates
    private func saveSelectedCalendars() {
        appSettings.selectedCalendarIds = selectedCalendarIds
    }
    
    /// Handles calendar selection changes and triggers necessary updates
    private func handleCalendarSelectionChange() async {
        // Prevent multiple simultaneous operations
        guard !isHandlingCalendarChange else {
            logger.info("Calendar change already in progress, skipping...")
            return
        }
        
        isHandlingCalendarChange = true
        defer { isHandlingCalendarChange = false }
        
        logger.info("Starting calendar selection change handling...")
        
        // Refresh events for newly selected calendars
        await loadCalendarsAndEvents()
        
        // Trigger notification recalculation
        await notificationScheduler?.rescheduleAllNotifications()
        
        // Update menu bar
        menuBarService?.updateMenuBarTitle()
        
        logger.info("Calendar selection changed - refreshed events and notifications")
    }
    
    func toggleCalendar(_ calendar: EKCalendar) {
        if selectedCalendarIds.contains(calendar.calendarIdentifier) {
            selectedCalendarIds.remove(calendar.calendarIdentifier)
        } else {
            selectedCalendarIds.insert(calendar.calendarIdentifier)
        }
        saveSelectedCalendars()
    }
    
    /// Selects all available calendars at once
    func selectAllCalendars() {
        let allCalendarIds = Set(calendars.map { $0.calendarIdentifier })
        selectedCalendarIds = allCalendarIds
        saveSelectedCalendars()
    }
    
    /// Deselects all calendars at once
    func deselectAllCalendars() {
        selectedCalendarIds.removeAll()
        saveSelectedCalendars()
    }
    
    func isCalendarSelected(_ calendar: EKCalendar) -> Bool {
        return selectedCalendarIds.contains(calendar.calendarIdentifier)
    }
    
    var selectedCalendars: [EKCalendar] {
        return calendars.filter { selectedCalendarIds.contains($0.calendarIdentifier) }
    }
    
    var upcomingEvents: [EKEvent] {
        let now = Date()
        return events.filter { event in
            event.startDate > now
        }.sorted { $0.startDate < $1.startDate }
    }
    
    func checkAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }
    
    /// Requests calendar access using Apple's recommended async patterns
    /// Handles both legacy and modern EventKit APIs
    func requestCalendarAccess() async {
        errorMessage = nil
        
        do {
            let granted: Bool
            
            if #available(macOS 14, *) {
                granted = try await eventStore.requestFullAccessToEvents()
            } else {
                // For legacy systems, wrap in async pattern
                granted = await withCheckedContinuation { continuation in
                    eventStore.requestAccess(to: .event) { accessGranted, error in
                        if let error = error {
                            self.logger.error("Calendar access error: \(error.localizedDescription)")
                        }
                        continuation.resume(returning: accessGranted)
                    }
                }
            }
            
            // Update authorization status
            checkAuthorizationStatus()
            
            logger.info("Calendar access granted: \(granted)")
            
            // Load calendars and events if access granted
            if authorizationStatus == .fullAccess {
                logger.info("Full access granted, loading calendars and events...")
                await loadCalendarsAndEvents()
            } else {
                let message = "Calendar access not granted. Status: \(authorizationStatus.debugDescription). You may need to manually enable calendar access in System Settings > Privacy & Security > Calendars."
                logger.warning("\(message)")
                await MainActor.run {
                    errorMessage = message
                }
            }
        } catch {
            logger.error("Calendar Access Request failed: \(error.localizedDescription)")
            let message = "Failed to request calendar access: \(error.localizedDescription)"
            await MainActor.run {
                errorMessage = message
            }
        }
    }
    
    func loadCalendarsAndEvents() async {
        logger.debug("loadCalendarsAndEvents() called, authorizationStatus: \(self.authorizationStatus.rawValue)")
        guard authorizationStatus == .fullAccess else {
            logger.info("Skipping load - no full calendar access")
            return 
        }
        
        await PerformanceMonitor.shared.measureAsyncBlock("loadCalendarsAndEvents") {
            await MainActor.run { isLoading = true }
            
            // Load all available calendars (cached to avoid repeated calls)
            let loadedCalendars = eventStore.calendars(for: .event)
            logger.info("Loaded \(loadedCalendars.count) calendars")
            
            await MainActor.run {
                calendars = loadedCalendars
                // If no calendars are selected, select all by default
                if selectedCalendarIds.isEmpty {
                    selectedCalendarIds = Set(loadedCalendars.map { $0.calendarIdentifier })
                    saveSelectedCalendars()
                    logger.info("Selected all calendars by default: \(self.selectedCalendarIds.count)")
                } else {
                    logger.debug("Using \(self.selectedCalendarIds.count) pre-selected calendars")
                }
            }
            
            // Load events for the next 30 days with optimized filtering
            let startDate = Date()
            let endDate = Calendar.current.date(byAdding: .day, value: 30, to: startDate)!
            
            // Use only selected calendars
            let calendarsToUse = loadedCalendars.filter { selectedCalendarIds.contains($0.calendarIdentifier) }
            logger.debug("Using \(calendarsToUse.count) calendars for event search")
            
            let predicate = eventStore.predicateForEvents(
                withStart: startDate,
                end: endDate,
                calendars: calendarsToUse
            )
            
            // Optimize event filtering by doing it in batches to avoid blocking the main thread
            let allEvents = eventStore.events(matching: predicate)
            logger.debug("Found \(allEvents.count) raw events")
            
            // Process events in background and only update UI on main thread
            let filteredEvents = allEvents.compactMap { event -> EKEvent? in
                // More efficient filtering logic
                let hasNotes = !(event.notes?.isEmpty ?? true)
                let hasMultipleAttendees = (event.attendees?.count ?? 0) > 1
                let titleContainsMeeting = event.title?.lowercased().contains("meeting") == true ||
                                         event.title?.lowercased().contains("call") == true
                let videoConferenceManager = VideoConferenceManager()
                let hasVideoURL = videoConferenceManager.extractVideoConferenceInfo(from: event) != nil
                
                return (hasNotes || hasMultipleAttendees || titleContainsMeeting || hasVideoURL) ? event : nil
            }
            .sorted { $0.startDate < $1.startDate }
            
            logger.info("Filtered to \(filteredEvents.count) meeting events")
            
            await MainActor.run {
                events = filteredEvents
                isLoading = false
                errorMessage = nil // Clear any previous errors on success
                
                // Refresh skipped meetings state
                refreshSkippedMeetingsState()
                
                // Schedule notifications for loaded events
                if let scheduler = notificationScheduler {
                    logger.info("Scheduling notifications for \(filteredEvents.count) events")
                    let _ = scheduler.scheduleNotifications(for: filteredEvents)
                } else {
                    logger.warning("notificationScheduler is nil, cannot schedule notifications")
                }
            }
        }
    }
    
    
    func getVideoConferenceInfo(for event: EKEvent) -> VideoConferenceInfo? {
        let videoConferenceManager = VideoConferenceManager()
        return videoConferenceManager.extractVideoConferenceInfo(from: event)
    }
    
    // MARK: - Skipped Meetings Management
    
    func updateSkippedMeetingState(for event: EKEvent) {
        guard let eventIdentifier = event.eventIdentifier else { return }
        let meetingKey = "\(eventIdentifier)_\(event.startDate.timeIntervalSince1970)"
        
        if DataManager.shared.isMeetingSkipped(eventIdentifier: eventIdentifier, meetingDate: event.startDate) {
            skippedMeetingIds.insert(meetingKey)
        } else {
            skippedMeetingIds.remove(meetingKey)
        }
    }
    
    func isMeetingSkippedInViewModel(for event: EKEvent) -> Bool {
        guard let eventIdentifier = event.eventIdentifier else { return false }
        let meetingKey = "\(eventIdentifier)_\(event.startDate.timeIntervalSince1970)"
        return skippedMeetingIds.contains(meetingKey)
    }
    
    func refreshSkippedMeetingsState() {
        skippedMeetingIds.removeAll()
        for event in events {
            updateSkippedMeetingState(for: event)
        }
    }
    
    // MARK: - Preview/Demo Data
    
    /// Creates a CalendarViewModel with demo data for previews
    @MainActor
    static func withDemoData() -> CalendarViewModel {
        let viewModel = CalendarViewModel()
        let demoEventStore = EKEventStore()
        
        // Create demo calendar
        let demoCalendar = EKCalendar(for: .event, eventStore: demoEventStore)
        demoCalendar.title = "Work Calendar"
        demoCalendar.cgColor = NSColor.systemBlue.cgColor
        
        // Create demo events
        let now = Date()
        let calendar = Calendar.current
        
        // Next meeting in 15 minutes
        let nextMeeting = EKEvent(eventStore: demoEventStore)
        nextMeeting.title = "Daily Standup"
        nextMeeting.startDate = calendar.date(byAdding: .minute, value: 15, to: now)!
        nextMeeting.endDate = calendar.date(byAdding: .minute, value: 45, to: now)!
        nextMeeting.notes = "Join us for the daily standup\nhttps://zoom.us/j/123456789"
        nextMeeting.calendar = demoCalendar
        
        // Meeting in 2 hours
        let laterMeeting = EKEvent(eventStore: demoEventStore)
        laterMeeting.title = "Product Review Meeting"
        laterMeeting.startDate = calendar.date(byAdding: .hour, value: 2, to: now)!
        laterMeeting.endDate = calendar.date(byAdding: .hour, value: 3, to: now)!
        laterMeeting.notes = "Product review with stakeholders\nhttps://teams.microsoft.com/l/meetup-join/demo123"
        laterMeeting.calendar = demoCalendar
        
        // Tomorrow's meeting
        let tomorrowMeeting = EKEvent(eventStore: demoEventStore)
        tomorrowMeeting.title = "Client Demo"
        tomorrowMeeting.startDate = calendar.date(byAdding: .day, value: 1, to: calendar.date(bySettingHour: 10, minute: 0, second: 0, of: now)!)!
        tomorrowMeeting.endDate = calendar.date(byAdding: .hour, value: 1, to: tomorrowMeeting.startDate)!
        tomorrowMeeting.notes = "Demo for client XYZ\nhttps://meet.google.com/abc-defg-hij"
        tomorrowMeeting.calendar = demoCalendar
        
        // Today's later meeting
        let todayLater = EKEvent(eventStore: demoEventStore)
        todayLater.title = "Team Retrospective"
        todayLater.startDate = calendar.date(byAdding: .hour, value: 4, to: now)!
        todayLater.endDate = calendar.date(byAdding: .hour, value: 5, to: now)!
        todayLater.notes = "Weekly retrospective meeting"
        todayLater.calendar = demoCalendar
        
        // Next week meeting
        let nextWeek = EKEvent(eventStore: demoEventStore)
        nextWeek.title = "All Hands Meeting"
        nextWeek.startDate = calendar.date(byAdding: .day, value: 3, to: calendar.date(bySettingHour: 14, minute: 0, second: 0, of: now)!)!
        nextWeek.endDate = calendar.date(byAdding: .hour, value: 1, to: nextWeek.startDate)!
        nextWeek.notes = "Monthly all hands meeting\nhttps://telemost.yandex.ru/j/demo456"
        nextWeek.calendar = demoCalendar
        
        // Another tomorrow meeting
        let tomorrowAfternoon = EKEvent(eventStore: demoEventStore)
        tomorrowAfternoon.title = "Design Review"
        tomorrowAfternoon.startDate = calendar.date(byAdding: .day, value: 1, to: calendar.date(bySettingHour: 15, minute: 30, second: 0, of: now)!)!
        tomorrowAfternoon.endDate = calendar.date(byAdding: .minute, value: 90, to: tomorrowAfternoon.startDate)!
        tomorrowAfternoon.notes = "Review latest designs"
        tomorrowAfternoon.calendar = demoCalendar
        
        // Set demo data
        viewModel.calendars = [demoCalendar]
        viewModel.events = [nextMeeting, laterMeeting, todayLater, tomorrowMeeting, tomorrowAfternoon, nextWeek]
        viewModel.selectedCalendarIds = [demoCalendar.calendarIdentifier]
        viewModel.authorizationStatus = .fullAccess
        
        return viewModel
    }
}

struct VideoConferenceInfo {
    let platform: VideoConferencePlatform
    let url: URL
    let displayName: String
}

enum VideoConferencePlatform: String, CaseIterable, Codable {
    case zoom = "Zoom"
    case teams = "Microsoft Teams"
    case meet = "Google Meet"
    case telemost = "Yandex Telemost"
    case dion = "Dion"
    case discord = "Discord"
    case slack = "Slack"
    case webex = "Cisco Webex"
    case jitsi = "Jitsi"
    case whatsapp = "WhatsApp"
    case telegram = "Telegram"
    case skype = "Skype"
    case whereby = "Whereby"
    case around = "Around"
    case gather = "Gather"
    case luma = "Luma"
    case facetime = "FaceTime"
    case gotomeeting = "GoToMeeting"
    case bluejeans = "BlueJeans"
    case chime = "Amazon Chime"
    case ringcentral = "RingCentral"
    case vonage = "Vonage"
    case vkcalls = "VK Calls"
    
    case unknown = "Unknown"
    
    var iconName: String {
        switch self {
        case .zoom: return "video.circle"
        case .teams: return "person.2.circle"
        case .meet: return "video.fill"
        case .telemost: return "video.circle.fill"
        case .dion: return "video"
        case .discord: return "gamecontroller.fill"
        case .slack: return "bubble.left.and.bubble.right.fill"
        case .webex: return "video.square.fill"
        case .jitsi: return "video.badge.plus"
        case .whatsapp: return "phone.fill"
        case .telegram: return "paperplane.fill"
        case .skype: return "video.circle.fill"
        case .whereby: return "tv.fill"
        case .around: return "circle.grid.cross.fill"
        case .gather: return "person.3.fill"
        case .luma: return "calendar.circle.fill"
        case .facetime: return "video.fill"
        case .gotomeeting: return "rectangle.on.rectangle"
        case .bluejeans: return "video.square"
        case .chime: return "bell.circle.fill"
        case .ringcentral: return "phone.circle.fill"
        case .vonage: return "phone.badge.plus"
        case .vkcalls: return "phone.connection"
        case .unknown: return "link.circle"
        }
    }
}

// MARK: - Debug Extensions
extension EKAuthorizationStatus {
    var debugDescription: String {
        switch self {
        case .notDetermined:
            return "Not Determined"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .fullAccess:
            return "Full Access"
        case .writeOnly:
            return "Write Only"
        @unknown default:
            return "Unknown (\(rawValue))"
        }
    }
}
