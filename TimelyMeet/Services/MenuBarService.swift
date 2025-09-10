//
//  MenuBarService.swift
//  TimelyMeet
//
//  Created by Roman Makarskiy on 26.08.2025.
//

import SwiftUI
import EventKit
import Combine

@MainActor
class MenuBarService: ObservableObject {
    @Published var timeToNextMeeting: String = "No meetings"
    @Published var nextMeetingEvent: EKEvent?
    
    private let appSettings = AppSettings.shared
    
    // Computed property that automatically reacts to changes
    var shouldShowMeetingInfo: Bool {
        guard let calendarViewModel = calendarViewModel else { return false }
        
        let now = Date()
        let thresholdDate = now.addingTimeInterval(appSettings.menuBarDisplayThreshold * 3600)
        
        let upcomingEvents = calendarViewModel.events.filter { event in
            event.startDate > now && event.startDate <= thresholdDate
        }
        
        return !upcomingEvents.isEmpty
    }
    
    private var calendarViewModel: CalendarViewModel?
    private var updateTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []
    
    init() {
        startPeriodicUpdate()
        observeSettingsChanges()
    }
    
    private func observeSettingsChanges() {
        appSettings.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateMenuBarTitle()
                self?.objectWillChange.send()
            }
        }.store(in: &cancellables)
    }
    
    func updateDisplayThreshold(hours: Double) {
        appSettings.menuBarDisplayThreshold = hours
        updateMenuBarTitle()
    }
    
    func updateDisplayOptions(showTime: Bool, showEventTitle: Bool) {
        appSettings.menuBarShowTime = showTime
        appSettings.menuBarShowEventTitle = showEventTitle
        updateMenuBarTitle()
    }
    
    deinit {
        updateTimer?.invalidate()
    }
    
    func setCalendarViewModel(_ viewModel: CalendarViewModel) {
        self.calendarViewModel = viewModel
        
        updateMenuBarTitle()
        
        // Listen for changes in the events array specifically
        viewModel.$events.sink { [weak self] events in
            DispatchQueue.main.async {
                self?.updateMenuBarTitle()
            }
        }.store(in: &cancellables)
    }
    
    private func startPeriodicUpdate() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMenuBarTitle()
            }
        }
    }
    
    public func updateMenuBarTitle() {
        guard let calendarViewModel = calendarViewModel else {
            timeToNextMeeting = "No meetings"
            nextMeetingEvent = nil
            return
        }
        
        let now = Date()
        let thresholdDate = now.addingTimeInterval(appSettings.menuBarDisplayThreshold * 3600) // Convert hours to seconds
        
        let allEvents = calendarViewModel.events
        let futureEvents = allEvents.filter { $0.startDate > now }
        let upcomingEvents = futureEvents.filter { event in
            event.startDate <= thresholdDate
        }.sorted { $0.startDate < $1.startDate }
        
        if let nextEvent = upcomingEvents.first {
            nextMeetingEvent = nextEvent
            timeToNextMeeting = formatMenuBarText(for: nextEvent)
        } else {
            // Check if there are any meetings beyond the threshold
            let allUpcomingEvents = calendarViewModel.events.filter { event in
                event.startDate > now
            }.sorted { $0.startDate < $1.startDate }
            
            if let nextEvent = allUpcomingEvents.first {
                nextMeetingEvent = nextEvent
                timeToNextMeeting = "No meetings"
            } else {
                nextMeetingEvent = nil
                timeToNextMeeting = "No meetings"
            }
        }
        
        // Force UI update for computed property
        objectWillChange.send()
    }
    
    private func formatMenuBarText(for event: EKEvent) -> String {
        var components: [String] = []
        
        if appSettings.menuBarShowTime {
            components.append(formatTimeUntilMeeting(event.startDate))
        }
        
        if appSettings.menuBarShowEventTitle {
            let eventTitle = event.title ?? "Meeting"
            let truncatedTitle = String(eventTitle.prefix(30))
            components.append(truncatedTitle)
        }
        
        if components.isEmpty {
            return "Meeting Soon"
        }
        
        return components.joined(separator: " - ")
    }
    
    private func formatTimeUntilMeeting(_ date: Date) -> String {
        let now = Date()
        let timeInterval = date.timeIntervalSince(now)
        
        if timeInterval < 0 {
            return "Started"
        } else if timeInterval < 60 {
            return "Now"
        } else if timeInterval < 3600 { // Less than 1 hour
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m"
        } else if timeInterval < 86400 { // Less than 24 hours
            let hours = Int(timeInterval / 3600)
            let minutes = Int((timeInterval.truncatingRemainder(dividingBy: 3600)) / 60)
            if minutes == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(minutes)m"
            }
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }
    
    func getMenuBarIcon() -> String {
        guard let nextEvent = nextMeetingEvent else {
            return "calendar"
        }
        
        let now = Date()
        let timeInterval = nextEvent.startDate.timeIntervalSince(now)
        
        if timeInterval < 300 { // 5 minutes
            return "clock.badge.exclamationmark"
        } else if timeInterval < 900 { // 15 minutes
            return "clock.badge"
        } else {
            return "calendar.circle"
        }
    }
}
