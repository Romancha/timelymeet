//
//  MenuBarView.swift
//  TimelyMeet
//
//  Created by Roman Makarskiy on 26.08.2025.
//

import SwiftUI
import EventKit
import AppKit
import OSLog

extension EKEvent {
    var uniqueID: String {
        let baseID = eventIdentifier ?? UUID().uuidString
        let timestamp = startDate.timeIntervalSince1970
        return "\(baseID)-\(timestamp)"
    }
}

struct MenuBarView: View {
    @EnvironmentObject private var calendarViewModel: CalendarViewModel
    @EnvironmentObject private var notificationScheduler: NotificationScheduler
    
    private let logger = Logger(subsystem: "org.romancha.timelymeet", category: "MenuBarView")
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Calendar permission notification (if needed)
            CalendarPermissionNotification()
            
            // Next meeting section
            NextMeetingSection()
            
            Divider()
                .padding(.vertical, 8)
            
            // Upcoming meetings list
            UpcomingMeetingsSection()
            
            Divider()
                .padding(.vertical, 8)
            
            // Quick actions
            QuickActionsSection()
        }
        .padding(12)
        .frame(minWidth: 320, maxWidth: 320, alignment: .leading)
        .background(Color.clear)
    }
}

struct NextMeetingSection: View {
    @EnvironmentObject private var calendarViewModel: CalendarViewModel
    @EnvironmentObject private var notificationScheduler: NotificationScheduler
    @Environment(\.managedObjectContext) private var managedObjectContext
    
    private let logger = Logger(subsystem: "org.romancha.timelymeet", category: "NextMeetingSection")
    
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "clock.fill")
                Text("next_meeting".localized())
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if let nextEvent = calendarViewModel.upcomingEvents.first {
                let isSkipped = calendarViewModel.isMeetingSkippedInViewModel(for: nextEvent)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(nextEvent.title ?? "untitled".localized())
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .strikethrough(isSkipped)
                            .foregroundColor(isSkipped ? .primary : .secondary)
                        
                        if isSkipped {
                            Image(systemName: "bell.slash")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Skip/Unskip button
                        Button(action: {
                            if isSkipped {
                                unskipMeeting(nextEvent)
                            } else {
                                skipMeeting(nextEvent)
                            }
                        }) {
                            Image(systemName: isSkipped ? "bell" : "bell.slash")
                                .font(.caption)
                                .foregroundColor(isSkipped ? .secondary : .primary)
                        }
                        .buttonStyle(.plain)
                        .help(isSkipped ? "enable_notifications_meeting".localized() : "skip_notifications_meeting".localized())
                        
                        Circle()
                            .fill(Color(nextEvent.calendar.cgColor))
                            .frame(width: 8, height: 8)
                    }
                    
                    HStack {
                        Text(timeUntilMeeting(nextEvent))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(isSkipped ? .secondary : .primary)
                            .fontWeight(.semibold)
                        Spacer()
                        Text(nextEvent.startDate, style: .time)
                            .font(.caption)
                            .fontWeight(.light)
                            .foregroundColor(.secondary)
                    }
                    
                    if let videoInfo = calendarViewModel.getVideoConferenceInfo(for: nextEvent) {
                        Button(action: {
                            if !isSkipped {
                                Task {
                                    try? await VideoConferenceManager().joinMeeting(url: videoInfo.url)
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: videoInfo.platform.iconName)
                                Text("Join \(videoInfo.platform.rawValue)")
                            }
                            .font(.caption)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(isSkipped)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(8)
            } else {
                Text("no_upcoming_meetings".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            }
        }
    }
    
    private func timeUntilMeeting(_ event: EKEvent) -> String {
        let now = Date()
        let timeInterval = event.startDate.timeIntervalSince(now)
        
        if timeInterval < 0 {
            return "status_started".localized()
        } else if timeInterval < 60 {
            return "status_starting_now".localized()
        } else if timeInterval < 3600 { // Less than 1 hour
            let minutes = Int(timeInterval / 60)
            return "in \(minutes)m"
        } else if timeInterval < 86400 { // Less than 24 hours
            let hours = Int(timeInterval / 3600)
            let minutes = Int((timeInterval.truncatingRemainder(dividingBy: 3600)) / 60)
            return "in \(hours)h \(minutes)m"
        } else {
            let days = Int(timeInterval / 86400)
            return "in \(days)d"
        }
    }
    
    private func skipMeeting(_ event: EKEvent) {
        guard let eventIdentifier = event.eventIdentifier else { return }
        
        DataManager.shared.skipMeeting(
            eventIdentifier: eventIdentifier,
            eventTitle: event.title,
            meetingDate: event.startDate,
            calendarIdentifier: event.calendar.calendarIdentifier
        )
        
        // Update shared state
        calendarViewModel.updateSkippedMeetingState(for: event)
        
        // Refresh notifications to respect the new skip status
        Task {
            await refreshNotifications()
        }
    }
    
    private func unskipMeeting(_ event: EKEvent) {
        guard let eventIdentifier = event.eventIdentifier else { return }
        
        DataManager.shared.unskipMeeting(eventIdentifier: eventIdentifier, meetingDate: event.startDate)
        
        // Update shared state
        calendarViewModel.updateSkippedMeetingState(for: event)
        
        // Refresh notifications to respect the new skip status
        Task {
            await refreshNotifications()
        }
    }
    
    @MainActor
    private func refreshNotifications() async {
        logger.debug("refreshNotifications() called with \(calendarViewModel.events.count) events")
        // Re-schedule all notifications with the updated skip status
        let _ = notificationScheduler.scheduleNotifications(for: calendarViewModel.events)
        logger.debug("refreshNotifications() completed")
    }
}

struct UpcomingMeetingsSection: View {
    @EnvironmentObject private var calendarViewModel: CalendarViewModel
    
    private let maxDisplayEvents = 8
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.primary)
                Text("upcoming".localized())
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(calendarViewModel.upcomingEvents.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if calendarViewModel.upcomingEvents.isEmpty {
                Text("no_meetings_found".localized())
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                let groupedEvents = groupEventsByDay(calendarViewModel.upcomingEvents, maxEvents: maxDisplayEvents)
                
                ForEach(groupedEvents, id: \.title) { group in
                    VStack(alignment: .leading, spacing: 4) {
                        // Group header
                        HStack {
                            Text(group.title.localized())
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(group.color)
                            
                            Rectangle()
                                .fill(group.color.opacity(0.3))
                                .frame(height: 1)
                            
                            if !group.events.isEmpty {
                                Text("\(group.events.count)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Events in this group
                        ForEach(group.events, id: \.uniqueID) { event in
                            MenuBarEventRow(event: event, showDate: group.showDate)
                                .padding(.leading, 8)
                        }
                    }
                    .padding(.vertical, 2)
                }
                
                let totalShown = groupedEvents.reduce(0) { $0 + $1.events.count }
                if calendarViewModel.upcomingEvents.count > totalShown {
                    Text("+ \(calendarViewModel.upcomingEvents.count - totalShown) more")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
        }
    }
    
    private func groupEventsByDay(_ events: [EKEvent], maxEvents: Int) -> [EventGroup] {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        var groups: [EventGroup] = []
        var eventCount = 0
        
        // Today's events
        let todayEvents = events.filter { event in
            calendar.isDate(event.startDate, inSameDayAs: today) && eventCount < maxEvents
        }.prefix(maxEvents - eventCount)
        
        if !todayEvents.isEmpty {
            groups.append(EventGroup(
                title: "Today",
                color: .primary,
                events: Array(todayEvents),
                showDate: false
            ))
            eventCount += todayEvents.count
        }
        
        // Tomorrow's events
        if eventCount < maxEvents {
            let tomorrowEvents = events.filter { event in
                calendar.isDate(event.startDate, inSameDayAs: tomorrow) && eventCount < maxEvents
            }.prefix(maxEvents - eventCount)
            
            if !tomorrowEvents.isEmpty {
                groups.append(EventGroup(
                    title: "Tomorrow",
                    color: .secondary,
                    events: Array(tomorrowEvents),
                    showDate: false
                ))
                eventCount += tomorrowEvents.count
            }
        }
        
        // Other events (future days)
        if eventCount < maxEvents {
            let otherEvents = events.filter { event in
                !calendar.isDate(event.startDate, inSameDayAs: today) &&
                !calendar.isDate(event.startDate, inSameDayAs: tomorrow) &&
                event.startDate > tomorrow
            }.prefix(maxEvents - eventCount)
            
            if !otherEvents.isEmpty {
                groups.append(EventGroup(
                    title: "Later",
                    color: .secondary,
                    events: Array(otherEvents),
                    showDate: true
                ))
            }
        }
        
        return groups
    }
}

struct EventGroup {
    let title: String
    let color: Color
    let events: [EKEvent]
    let showDate: Bool
}

struct MenuBarEventRow: View {
    let event: EKEvent
    let showDate: Bool
    @EnvironmentObject private var calendarViewModel: CalendarViewModel
    @EnvironmentObject private var notificationScheduler: NotificationScheduler
    @Environment(\.managedObjectContext) private var managedObjectContext
    
    private let logger = Logger(subsystem: "org.romancha.timelymeet", category: "MenuBarEventRow")
    
    
    private static let dayMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter
    }()
    
    init(event: EKEvent, showDate: Bool = true) {
        self.event = event
        self.showDate = showDate
    }
    
    var body: some View {
        let isSkipped = calendarViewModel.isMeetingSkippedInViewModel(for: event)
        
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.startDate, style: .time)
                    .font(.caption)
                    .fontWeight(.medium)
                
                if showDate {
                    Text(Self.dayMonthFormatter.string(from: event.startDate))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 50, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(event.title ?? "untitled".localized())
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .strikethrough(isSkipped)
                        .foregroundColor(isSkipped ? .secondary : .primary)
                    
                    if isSkipped {
                        Image(systemName: "bell.slash")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let videoInfo = calendarViewModel.getVideoConferenceInfo(for: event) {
                    HStack(spacing: 4) {
                        Image(systemName: videoInfo.platform.iconName)
                        Text(videoInfo.platform.rawValue)
                    }
                    .fontWeight(.light)
                    .font(.caption2)
                    .foregroundColor(isSkipped ? .secondary : .primary)
                }
            }
            
            Spacer()
            
            // Skip/Unskip button
            Button(action: {
                if isSkipped {
                    unskipMeeting()
                } else {
                    skipMeeting()
                }
            }) {
                Image(systemName: isSkipped ? "bell" : "bell.slash")
                    .font(.caption)
                    .foregroundColor(isSkipped ? .secondary : .primary)
            }
            .buttonStyle(.plain)
            .help(isSkipped ? "enable_notifications_meeting".localized() : "skip_notifications_meeting".localized())
            
            Circle()
                .fill(Color(event.calendar.cgColor))
                .frame(width: 6, height: 6)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isSkipped, let videoInfo = calendarViewModel.getVideoConferenceInfo(for: event) {
                Task {
                    try? await VideoConferenceManager().joinMeeting(url: videoInfo.url)
                }
            }
        }
    }
    
    private func skipMeeting() {
        guard let eventIdentifier = event.eventIdentifier else { return }
        
        DataManager.shared.skipMeeting(
            eventIdentifier: eventIdentifier,
            eventTitle: event.title,
            meetingDate: event.startDate,
            calendarIdentifier: event.calendar.calendarIdentifier
        )
        
        // Update shared state
        calendarViewModel.updateSkippedMeetingState(for: event)
        
        // Refresh notifications to respect the new skip status
        Task {
            await refreshNotifications()
        }
    }
    
    private func unskipMeeting() {
        guard let eventIdentifier = event.eventIdentifier else { return }
        
        DataManager.shared.unskipMeeting(eventIdentifier: eventIdentifier, meetingDate: event.startDate)
        
        // Update shared state
        calendarViewModel.updateSkippedMeetingState(for: event)
        
        // Refresh notifications to respect the new skip status
        Task {
            await refreshNotifications()
        }
    }
    
    @MainActor
    private func refreshNotifications() async {
        logger.debug("refreshNotifications() called with \(calendarViewModel.events.count) events")
        // Re-schedule all notifications with the updated skip status
        let _ = notificationScheduler.scheduleNotifications(for: calendarViewModel.events)
        logger.debug("refreshNotifications() completed")
    }
}

struct QuickActionsSection: View {
    @EnvironmentObject private var calendarViewModel: CalendarViewModel
    @EnvironmentObject private var menuBarService: MenuBarService
    @EnvironmentObject private var fullscreenService: FullscreenNotificationService
    @EnvironmentObject private var analyticsService: MeetingAnalyticsService
    @EnvironmentObject private var customSoundService: CustomSoundService
    @EnvironmentObject private var themeService: NotificationThemeService
    @EnvironmentObject private var developerModeService: DeveloperModeService
    @EnvironmentObject private var notificationScheduler: NotificationScheduler
    @EnvironmentObject private var backgroundSync: BackgroundSyncService
    
    @State private var shouldOpenSettings = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Button(action: {
                        Task {
                            await calendarViewModel.loadCalendarsAndEvents()
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("refresh".localized())
                        }
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(calendarViewModel.isLoading)
                    
                    Button(action: {
                        // Close menu first, then open settings (Apple HIG guidelines)
                        if let menuBarExtra = NSApp.windows.first(where: { $0.className.contains("MenuBarExtra") }) {
                            menuBarExtra.orderOut(nil)
                        }
                        
                        // Slight delay to ensure menu closes before opening settings
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            shouldOpenSettings = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "gearshape")
                            Text("settings".localized())
                        }
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    HStack {
                        Image(systemName: "power")
                        Text("quit".localized())
                    }
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .onChange(of: shouldOpenSettings) { _, newValue in
            if newValue {
                // Reset flag immediately
                shouldOpenSettings = false
                
                // Open settings outside of view update cycle
                DispatchQueue.main.async {
                    SettingsWindowManager.shared.openSettings(
                        calendarViewModel: calendarViewModel,
                        menuBarService: menuBarService,
                        fullscreenService: fullscreenService,
                        analyticsService: analyticsService,
                        customSoundService: customSoundService,
                        themeService: themeService,
                        developerModeService: developerModeService,
                        notificationScheduler: notificationScheduler,
                        backgroundSync: backgroundSync
                    )
                }
            }
        }
    }
}


#Preview {
    MenuBarView()
        .environmentObject(CalendarViewModel.withDemoData())
        .environmentObject(MenuBarService())
        .environmentObject(NotificationScheduler(
            fullscreenService: FullscreenNotificationService(themeService: NotificationThemeService())
        ))
}
