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
    @State private var currentTime = Date()
    @State private var timerCancellable: Timer?

    private let logger = Logger(subsystem: "org.romancha.timelymeet", category: "MenuBarView")

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Calendar permission notification (if needed)
            CalendarPermissionNotification()

            // Next meeting section
            NextMeetingSection(currentTime: currentTime)

            Divider()
                .padding(.vertical, 6)

            // Today's meetings section
            TodayMeetingsSection(currentTime: currentTime)

            Divider()
                .padding(.vertical, 6)

            // Upcoming meetings list
            UpcomingMeetingsSection(currentTime: currentTime)

            Divider()
                .padding(.vertical, 6)

            // Quick actions
            QuickActionsSection()
        }
        .padding(10)
        .frame(minWidth: 320, maxWidth: 320, alignment: .leading)
        .background(Color.clear)
        .onAppear {
            currentTime = Date()
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }

    private func startTimer() {
        stopTimer() // Ensure no duplicate timers
        timerCancellable = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            currentTime = Date()
        }
        logger.debug("Timer started for MenuBarView")
    }

    private func stopTimer() {
        timerCancellable?.invalidate()
        timerCancellable = nil
        logger.debug("Timer stopped for MenuBarView")
    }
}

struct NextMeetingSection: View {
    @EnvironmentObject private var calendarViewModel: CalendarViewModel
    @EnvironmentObject private var notificationScheduler: NotificationScheduler
    @Environment(\.managedObjectContext) private var managedObjectContext
    let currentTime: Date

    private let logger = Logger(subsystem: "org.romancha.timelymeet", category: "NextMeetingSection")
    
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.primary)
                    .symbolRenderingMode(.hierarchical)
                Text("next_meeting".localized())
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            // Show current meeting first, then next upcoming meeting
            let displayEvent = calendarViewModel.currentMeeting ?? calendarViewModel.upcomingEvents.first
            if let nextEvent = displayEvent {
                let isSkipped = calendarViewModel.isMeetingSkippedInViewModel(for: nextEvent)
                let meetingStatus = calendarViewModel.getMeetingStatus(for: nextEvent)
                let isCurrent = meetingStatus == .current

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(nextEvent.title ?? "untitled".localized())
                            .font(.subheadline)
                            .fontWeight(isCurrent ? .semibold : .medium)
                            .strikethrough(isSkipped)
                            .foregroundColor(
                                isSkipped ? .primary :
                                isCurrent ? .primary : .secondary
                            )

                        // Current meeting indicator
                        if isCurrent {
                            Image(systemName: "circle.inset.filled")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                        }

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
                            .fontWeight(.semibold)
                            .foregroundColor(
                                isSkipped ? .secondary :
                                isCurrent ? .accentColor : .primary
                            )
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
                                Text("\("join_meeting".localized()) \(videoInfo.platform.rawValue)")
                            }
                            .font(.caption)
                        }
                        .buttonStyle(.liquidGlass(isProminent: true, size: .mini))
                        .disabled(isSkipped)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isCurrent ? Color.accentColor.opacity(0.08) : Color.blue.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(isCurrent ? Color.accentColor.opacity(0.2) : Color.clear, lineWidth: 0.5)
                        )
                )
            } else {
                Text("no_upcoming_meetings".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            }
        }
    }
    
    private func timeUntilMeeting(_ event: EKEvent) -> String {
        let meetingStatus = calendarViewModel.getMeetingStatus(for: event)
        let now = currentTime

        switch meetingStatus {
        case .current:
            let endTimeInterval = event.endDate.timeIntervalSince(now)
            if endTimeInterval < 60 {
                return "status_ending_now".localized()
            } else if endTimeInterval < 3600 {
                let minutes = Int(endTimeInterval / 60)
                return "\(minutes)m " + "remaining".localized()
            } else {
                let hours = Int(endTimeInterval / 3600)
                let minutes = Int((endTimeInterval.truncatingRemainder(dividingBy: 3600)) / 60)
                if minutes == 0 {
                    return "\(hours)h " + "remaining".localized()
                } else {
                    return "\(hours)h \(minutes)m " + "remaining".localized()
                }
            }
        case .upcoming:
            let timeInterval = event.startDate.timeIntervalSince(now)
            if timeInterval < 60 {
                return "status_starting_now".localized()
            } else if timeInterval < 3600 { // Less than 1 hour
                let minutes = Int(timeInterval / 60)
                return String(format: "in_minutes".localized(), minutes)
            } else if timeInterval < 86400 { // Less than 24 hours
                let hours = Int(timeInterval / 3600)
                let minutes = Int((timeInterval.truncatingRemainder(dividingBy: 3600)) / 60)
                return String(format: "in_hours_minutes".localized(), hours, minutes)
            } else {
                let days = Int(timeInterval / 86400)
                return String(format: "in_days".localized(), days)
            }
        case .past:
            return "status_ended".localized()
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

struct TodayMeetingsSection: View {
    @EnvironmentObject private var calendarViewModel: CalendarViewModel
    let currentTime: Date

    private let maxDisplayEvents = 6

    var body: some View {
        let todayEvents = Array(calendarViewModel.todayEvents.prefix(maxDisplayEvents))

        if !todayEvents.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "calendar.circle")
                        .foregroundColor(.primary)
                        .symbolRenderingMode(.hierarchical)
                    Text("today_section".localized())
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(todayEvents.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                ForEach(Array(todayEvents.prefix(maxDisplayEvents)), id: \.uniqueID) { event in
                    MenuBarEventRow(event: event, showDate: false, currentTime: currentTime)
                }

                if todayEvents.count > maxDisplayEvents {
                    Text(String(format: "more_count".localized(), todayEvents.count - maxDisplayEvents))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
        }
    }
}

struct UpcomingMeetingsSection: View {
    @EnvironmentObject private var calendarViewModel: CalendarViewModel
    let currentTime: Date

    private let maxDisplayEvents = 8
    
    var body: some View {
        // Use only non-today events for upcoming section
        let upcomingEventsOnly = calendarViewModel.upcomingEvents

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.primary)
                    .symbolRenderingMode(.hierarchical)
                Text("upcoming".localized())
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(upcomingEventsOnly.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if upcomingEventsOnly.isEmpty {
                Text("no_meetings_found".localized())
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                let groupedEvents = groupEventsByDay(upcomingEventsOnly, maxEvents: maxDisplayEvents)
                
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
                            MenuBarEventRow(event: event, showDate: group.showDate, currentTime: currentTime)
                                .padding(.leading, 8)
                        }
                    }
                    .padding(.vertical, 2)
                }
                
                let totalShown = groupedEvents.reduce(0) { $0 + $1.events.count }
                if upcomingEventsOnly.count > totalShown {
                    Text(String(format: "more_count".localized(), upcomingEventsOnly.count - totalShown))
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

        // Tomorrow's events (only upcoming)
        let tomorrowEvents = events.filter { event in
            calendar.isDate(event.startDate, inSameDayAs: tomorrow) &&
            event.startDate > now
        }.prefix(maxEvents - eventCount)

        if !tomorrowEvents.isEmpty {
            groups.append(EventGroup(
                title: "tomorrow_section".localized(),
                color: .secondary,
                events: Array(tomorrowEvents),
                showDate: false
            ))
            eventCount += tomorrowEvents.count
        }

        // Other events (future days only)
        if eventCount < maxEvents {
            let otherEvents = events.filter { event in
                !calendar.isDate(event.startDate, inSameDayAs: today) &&
                !calendar.isDate(event.startDate, inSameDayAs: tomorrow) &&
                event.startDate > tomorrow
            }.prefix(maxEvents - eventCount)

            if !otherEvents.isEmpty {
                groups.append(EventGroup(
                    title: "later_section".localized(),
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
    let currentTime: Date
    @EnvironmentObject private var calendarViewModel: CalendarViewModel
    @EnvironmentObject private var notificationScheduler: NotificationScheduler
    @Environment(\.managedObjectContext) private var managedObjectContext

    private let logger = Logger(subsystem: "org.romancha.timelymeet", category: "MenuBarEventRow")
    
    
    private static let dayMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter
    }()
    
    init(event: EKEvent, showDate: Bool = true, currentTime: Date = Date()) {
        self.event = event
        self.showDate = showDate
        self.currentTime = currentTime
    }
    
    var body: some View {
        let isSkipped = calendarViewModel.isMeetingSkippedInViewModel(for: event)
        let meetingStatus = calendarViewModel.getMeetingStatus(for: event)

        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.startDate, style: .time)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(meetingStatus == .past ? .secondary : .primary)

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
                        .fontWeight(meetingStatus == .current ? .medium : .regular)
                        .lineLimit(1)
                        .strikethrough(isSkipped || meetingStatus == .past)
                        .foregroundColor(
                            isSkipped ? .secondary :
                            meetingStatus == .current ? .primary :
                            meetingStatus == .past ? .secondary : .primary
                        )

                    // Meeting status indicator
                    switch meetingStatus {
                    case .current:
                        Image(systemName: "circle.inset.filled")
                            .font(.caption2)
                            .foregroundColor(.accentColor)
                    case .past:
                        Image(systemName: "checkmark.circle")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    case .upcoming:
                        EmptyView()
                    }

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
                    .foregroundColor(
                        isSkipped || meetingStatus == .past ? .secondary :
                        meetingStatus == .current ? .accentColor : .primary
                    )
                }

                // Status text for current/past meetings
                if meetingStatus != .upcoming {
                    Text(meetingStatus == .current ? "status_ongoing".localized() : "status_ended".localized())
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(meetingStatus == .current ? .accentColor : .secondary)
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
                .opacity(meetingStatus == .past ? 0.5 : 1.0)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(meetingStatus == .current ? Color.accentColor.opacity(0.06) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(meetingStatus == .current ? Color.accentColor.opacity(0.15) : Color.clear, lineWidth: 0.5)
                )
        )
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
            HStack(spacing: 12) {
                Spacer()

                Button(action: {
                    Task {
                        await calendarViewModel.loadCalendarsAndEvents()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(calendarViewModel.isLoading)
                .help("refresh".localized())

                Divider()
                    .frame(height: 12)

                Button(action: {
                    // Close menu first, then open about (Apple HIG guidelines)
                    if let menuBarExtra = NSApp.windows.first(where: { $0.className.contains("MenuBarExtra") }) {
                        menuBarExtra.orderOut(nil)
                    }

                    // Slight delay to ensure menu closes before opening about
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        SettingsWindowManager.shared.openAbout()
                    }
                }) {
                    Image(systemName: "info.circle")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("about_meetalert".localized())

                Divider()
                    .frame(height: 12)

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
                    Image(systemName: "gearshape")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("settings".localized())

                Divider()
                    .frame(height: 12)

                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Image(systemName: "power")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("quit".localized())
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(0.03))
            )
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
