//
//  DeveloperModeView.swift
//  TimelyMeet
//
//  
//

import SwiftUI
import UserNotifications
import EventKit
import OSLog

struct DeveloperModeView: View {
    @State private var isDevModeEnabled = false
    @State private var selectedEventStartDate: Date = {
        let date = Date().addingTimeInterval(300) // 5 minutes from now
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return calendar.date(from: components) ?? date
    }()
    @State private var alertMessage = ""
    private let logger = Logger(subsystem: "org.romancha.timelymeet", category: "DeveloperModeView")
    @State private var lastTestTime: Date?
    @State private var notificationScheduler: NotificationScheduler?
    
    @EnvironmentObject private var developerModeService: DeveloperModeService
    @EnvironmentObject private var notificationSchedulerEnv: NotificationScheduler
    @EnvironmentObject private var videoConferenceManager: VideoConferenceManager
    
    private let userDefaults = UserDefaults.standard
    private let devModeKey = "devModeEnabled"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            developerModeHeader
            
            if isDevModeEnabled {
                testNotificationSection
            } else {
                enableDeveloperModeSection
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .onAppear {
            loadSettings()
            notificationScheduler = notificationSchedulerEnv
        }
    }
    
    // MARK: - Header Section
    
    private var developerModeHeader: some View {
        HStack {
            Image(systemName: "hammer.fill")
                .foregroundColor(.orange)
                .font(.title2)
            
            VStack(alignment: .leading) {
                Text("developer_mode".localized())
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("testing_tools_description".localized())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isDevModeEnabled)
                .toggleStyle(SwitchToggleStyle())
                .onChange(of: isDevModeEnabled) {
                    saveSettings()
                }
        }
    }
    
    // MARK: - Enable Developer Mode Section
    
    private var enableDeveloperModeSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.largeTitle)
            
            Text("developer_mode_disabled".localized())
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("enable_developer_mode_description".localized())
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("enable_developer_mode".localized()) {
                isDevModeEnabled = true
                saveSettings()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Test Notification Section
    
    private var testNotificationSection: some View {
        VStack(spacing: 16) {
            // Developer Settings
            GroupBox("developer_settings".localized()) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("enable_performance_monitoring".localized(), isOn: Binding(
                        get: { developerModeService.isPerformanceMonitoringEnabled },
                        set: { _ in developerModeService.togglePerformanceMonitoring() }
                    ))
                    .toggleStyle(SwitchToggleStyle())
                    
                    Text("performance_monitoring_description".localized())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            // Test Notifications
            GroupBox("quick_test_notifications".localized()) {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(spacing: 12) {
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("meetings_start_time".localized())
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                Button("reset_to_now_plus_5min".localized()) {
                                    let date = Date().addingTimeInterval(300)
                                    let calendar = Calendar.current
                                    let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                                    selectedEventStartDate = calendar.date(from: components) ?? date
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            
                            DatePicker("meeting_start_time".localized(), selection: Binding(
                                get: { selectedEventStartDate },
                                set: { newValue in
                                    // Set seconds to 00
                                    let calendar = Calendar.current
                                    let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: newValue)
                                    selectedEventStartDate = calendar.date(from: components) ?? newValue
                                }
                            ), displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.compact)
                                .labelsHidden()
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("test_meeting_url".localized())
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            TextField("meeting_url".localized(), text: Binding(
                                get: { developerModeService.testMeetingURL },
                                set: { newValue in
                                    developerModeService.updateTestMeetingURL(newValue)
                                }
                            ))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 12, design: .monospaced))
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(spacing: 12) {
                            Button("schedule_meeting_button".localized()) {
                                emulateCompleteWorkflow()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                    }
                    
                    VStack(spacing: 12) {
                        
                        // Fullscreen notifications
                        VStack(alignment: .leading, spacing: 6) {
                            Text("fullscreen_overlay_notifications".localized())
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 12) {
                                Button("show_fullscreen_now".localized()) {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                        developerModeService.testFullscreenNotification()
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                                
                                Button("test_meeting_join".localized()) {
                                    testMeetingJoin()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                            }
                        }
                    }
                    
                    // Scheduled notifications list
                    if !developerModeService.scheduledWorkflowNotifications.isEmpty {
                        scheduledNotificationsSection
                    }
                    
                    allScheduledNotificationsSection
                    
                    if let lastTestTime = lastTestTime {
                        Text("Last test: \(lastTestTime, formatter: testTimeFormatter)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    // MARK: - Scheduled Notifications Section
    
    private var scheduledNotificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("scheduled_workflow_notifications".localized())
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("cancel_all".localized()) {
                    developerModeService.cancelAllWorkflowNotifications()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundColor(.red)
            }
            
            LazyVStack(spacing: 8) {
                ForEach(developerModeService.scheduledWorkflowNotifications) { notification in
                    ScheduledNotificationRow(
                        notification: notification,
                        onCancel: {
                            developerModeService.cancelWorkflowNotification(notification.id)
                        }
                    )
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }
    
    // MARK: - All Scheduled Notifications Section
    
    private var allScheduledNotificationsSection: some View {
        GroupBox("all_meetalert_scheduled_notifications".localized()) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    let fullscreenCount = notificationScheduler?.scheduledNotifications.filter({ $0.type == .fullscreen }).count ?? 0
                    
                    Text("\(fullscreenCount) notifications")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        
                        Button("cancel_all".localized()) {
                            cancelAllSystemNotifications()
                            notificationScheduler?.cancelAllNotifications()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .foregroundColor(.red)
                        .disabled(fullscreenCount == 0)
                    }
                }
                
                if (notificationScheduler?.scheduledNotifications.isEmpty ?? true) {
                    Text("no_scheduled_notifications".localized())
                        .font(.body)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else {
                    LazyVStack(spacing: 6) {
                        if let scheduler = notificationScheduler {
                            ForEach(scheduler.scheduledNotifications.filter({ $0.type == .fullscreen }), id: \.id) { scheduledNotification in
                                FullscreenNotificationRow(notification: scheduledNotification) {
                                    scheduler.cancelNotification(withId: scheduledNotification.id)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadSettings() {
        isDevModeEnabled = userDefaults.bool(forKey: devModeKey)
    }
    
    private func saveSettings() {
        userDefaults.set(isDevModeEnabled, forKey: devModeKey)
    }
    
    private func cancelSystemNotification(_ identifier: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    private func cancelAllSystemNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
    }
    
    private func emulateCompleteWorkflow() {
        Task  {
            
            lastTestTime = Date()
            
            // Run the complete workflow emulation
            let success = await developerModeService.emulateFullWorkflow(eventStartDate: selectedEventStartDate)
            
            await MainActor.run {
                if success {
                    logger.info("Complete workflow emulation finished successfully! Check the scheduled notifications - they should fire at their planned times. Look at Console.app for detailed step-by-step logs")
                } else {
                    logger.error("Workflow emulation failed")
                }
            }
        }
    }
    
    private func testMeetingJoin() {
        Task {
            guard let url = URL(string: developerModeService.testMeetingURL) else {
                logger.error("Invalid meeting URL: \(developerModeService.testMeetingURL)")
                return
            }
            
            logger.info("Testing meeting join with URL: \(url.absoluteString)")
            
            do {
                try await videoConferenceManager.joinMeeting(url: url)
                logger.info("Meeting join test completed successfully!")
            } catch {
                logger.error("Meeting join test failed: \(error.localizedDescription)")
            }
        }
    }
    
    private var testTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }
    
}

// MARK: - Helper Functions

private func formatReminderTime(_ seconds: Int) -> String {
    if seconds < 60 {
        return "\(seconds)s before event"
    } else if seconds < 3600 {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        if remainingSeconds == 0 {
            return "\(minutes)m before event"
        } else {
            return "\(minutes)m \(remainingSeconds)s before event"
        }
    } else {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return "\(hours)h \(minutes)m before event"
    }
}

// MARK: - Scheduled Notification Row

struct ScheduledNotificationRow: View {
    let notification: ScheduledWorkflowNotification
    let onCancel: () -> Void
    
    @State private var timeRemaining: String = ""
    @State private var timer: Timer?
    
    var body: some View {
        HStack(spacing: 12) {
            // Type indicator
            Circle()
                .fill(Color(notification.typeColor))
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 4) {
                // Event title and type
                HStack {
                    Text(notification.eventTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(notification.typeDisplayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(notification.typeColor).opacity(0.2))
                        .foregroundColor(Color(notification.typeColor))
                        .cornerRadius(4)
                }
                
                // Timing information
                HStack {
                    Text("Notification: \(notification.formattedScheduledTime)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Event: \(notification.formattedEventTime)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(timeRemaining)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(notification.timeUntilNotification > 0 ? .green : .red)
                }
                
                // Reminder info
                Text(formatReminderTime(notification.reminderSeconds))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Cancel button
            Button("cancel".localized()) {
                onCancel()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .foregroundColor(.red)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
        .onAppear {
            updateTimeRemaining()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                updateTimeRemaining()
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func updateTimeRemaining() {
        let remaining = notification.timeUntilNotification
        
        if remaining <= 0 {
            timeRemaining = "status_fired".localized()
            timer?.invalidate()
        } else if remaining < 60 {
            timeRemaining = "in \(Int(remaining))s"
        } else if remaining < 3600 {
            let minutes = Int(remaining / 60)
            let seconds = Int(remaining.truncatingRemainder(dividingBy: 60))
            timeRemaining = "in \(minutes)m \(seconds)s"
        } else {
            let hours = Int(remaining / 3600)
            let minutes = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)
            timeRemaining = "in \(hours)h \(minutes)m"
        }
    }
}

// MARK: - Fullscreen Notification Row

struct FullscreenNotificationRow: View {
    let notification: ScheduledNotification
    let onCancel: () -> Void
    
    @State private var timeRemaining: String = ""
    @State private var timer: Timer?
    
    var body: some View {
        HStack(spacing: 10) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            
            VStack(alignment: .leading, spacing: 3) {
                // Notification title and meeting info
                HStack {
                    Text(notification.event.title ?? "Fullscreen Alert")
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                
                // Meeting time range
                Text("📅 \(meetingTimeRange)")
                    .font(.caption2)
                    .foregroundColor(.blue)
                    .lineLimit(1)
                
                // Notification timing information
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("🔔 \(formatFullDateTime(notification.scheduledTime))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(timeRemaining)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(timeUntilTrigger > 0 ? .green.opacity(0.9) : .red.opacity(0.9))
                    }
                    
                    Spacer()
                    
                    Text("ID: \(notification.id.uuidString.prefix(15))...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .opacity(0.7)
                }
            }
            
            // Cancel button
            Button("×") {
                onCancel()
            }
            .font(.caption)
            .foregroundColor(.red)
            .frame(width: 16, height: 16)
            .background(Color.red.opacity(0.05))
            .cornerRadius(8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.accentColor.opacity(0.2), lineWidth: 0.5)
        )
        .onAppear {
            updateTimeRemaining()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                updateTimeRemaining()
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private var timeUntilTrigger: TimeInterval {
        return notification.scheduledTime.timeIntervalSinceNow
    }
    
    private var statusColor: Color {
        let remaining = timeUntilTrigger
        if remaining <= 0 {
            return .red
        } else if remaining <= 300 { // 5 minutes
            return .orange
        } else {
            return .green
        }
    }
    
    private var meetingTimeRange: String {
        let startDate = notification.event.startDate!
        let endDate = notification.event.endDate!
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none
        
        let startTime = formatter.string(from: startDate)
        let endTime = formatter.string(from: endDate)
        let dateStr = dateFormatter.string(from: startDate)
        
        return "\(dateStr) \(startTime) - \(endTime)"
    }
    
    private func formatFullDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    private func updateTimeRemaining() {
        let remaining = timeUntilTrigger
        
        if remaining <= 0 {
            timeRemaining = "status_fired".localized()
            timer?.invalidate()
        } else if remaining < 60 {
            timeRemaining = "in \(Int(remaining))s"
        } else if remaining < 3600 {
            let minutes = Int(remaining / 60)
            let seconds = Int(remaining.truncatingRemainder(dividingBy: 60))
            timeRemaining = "in \(minutes)m \(seconds)s"
        } else {
            let hours = Int(remaining / 3600)
            let minutes = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)
            timeRemaining = "in \(hours)h \(minutes)m"
        }
    }
}

// MARK: - System Notification Row

struct SystemNotificationRow: View {
    let notification: UNNotificationRequest
    let onCancel: () -> Void
    
    @State private var timeRemaining: String = ""
    @State private var timer: Timer?
    
    var body: some View {
        HStack(spacing: 10) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            
            VStack(alignment: .leading, spacing: 3) {
                // Notification title and meeting info
                HStack {
                    Text(meetingTitle)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(notificationTypeText)
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(3)
                }
                
                // Meeting time range (if available)
                if let meetingTimeRange = meetingTimeRange {
                    Text("📅 \(meetingTimeRange)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
                
                // Notification timing information
                HStack {
                    if let triggerDate = triggerDate {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("🔔 \(formatFullDateTime(triggerDate))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Text(timeRemaining)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(timeUntilTrigger > 0 ? .green : .red)
                        }
                    } else {
                        Text("Unknown trigger time")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("ID: \(notification.identifier.prefix(8))...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .opacity(0.7)
                }
            }
            
            // Cancel button
            Button("×") {
                onCancel()
            }
            .font(.caption)
            .foregroundColor(.red)
            .frame(width: 16, height: 16)
            .background(Color.red.opacity(0.05))
            .cornerRadius(8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
        .onAppear {
            updateTimeRemaining()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                updateTimeRemaining()
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private var triggerDate: Date? {
        if let calendarTrigger = notification.trigger as? UNCalendarNotificationTrigger {
            return calendarTrigger.nextTriggerDate()
        } else if let timeIntervalTrigger = notification.trigger as? UNTimeIntervalNotificationTrigger {
            return Date().addingTimeInterval(timeIntervalTrigger.timeInterval)
        }
        return nil
    }
    
    private var timeUntilTrigger: TimeInterval {
        guard let triggerDate = triggerDate else { return 0 }
        return triggerDate.timeIntervalSinceNow
    }
    
    private var statusColor: Color {
        let remaining = timeUntilTrigger
        if remaining <= 0 {
            return .red
        } else if remaining <= 300 { // 5 minutes
            return .orange
        } else {
            return .green
        }
    }
    
    private var meetingTitle: String {
        // Try to get meeting title from userInfo first, then fall back to notification title
        if let eventTitle = notification.content.userInfo["eventTitle"] as? String {
            return eventTitle
        }
        return notification.content.title.isEmpty ? "System Notification" : notification.content.title
    }
    
    private var meetingStartDate: Date? {
        guard let startTimestamp = notification.content.userInfo["startDate"] as? TimeInterval else {
            return nil
        }
        return Date(timeIntervalSince1970: startTimestamp)
    }
    
    private var meetingEndDate: Date? {
        // Try to get end date from userInfo, fall back to estimated time
        if let endTimestamp = notification.content.userInfo["endDate"] as? TimeInterval {
            return Date(timeIntervalSince1970: endTimestamp)
        }
        
        // Fall back to estimated end date (start + 30 minutes)
        guard let startDate = meetingStartDate else { return nil }
        return startDate.addingTimeInterval(1800) // 30 minutes
    }
    
    private var meetingTimeRange: String? {
        guard let startDate = meetingStartDate else { return nil }
        let endDate = meetingEndDate ?? startDate.addingTimeInterval(1800)
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none
        
        let startTime = formatter.string(from: startDate)
        let endTime = formatter.string(from: endDate)
        let dateStr = dateFormatter.string(from: startDate)
        
        return "\(dateStr) \(startTime) - \(endTime)"
    }
    
    private var notificationTypeText: String {
        if let _ = notification.trigger as? UNCalendarNotificationTrigger {
            return "Calendar"
        } else if let _ = notification.trigger as? UNTimeIntervalNotificationTrigger {
            return "Timer"
        }
        return "Other"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatFullDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    private func updateTimeRemaining() {
        let remaining = timeUntilTrigger
        
        if remaining <= 0 {
            timeRemaining = "status_fired".localized()
            timer?.invalidate()
        } else if remaining < 60 {
            timeRemaining = "in \(Int(remaining))s"
        } else if remaining < 3600 {
            let minutes = Int(remaining / 60)
            let seconds = Int(remaining.truncatingRemainder(dividingBy: 60))
            timeRemaining = "in \(minutes)m \(seconds)s"
        } else {
            let hours = Int(remaining / 3600)
            let minutes = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)
            timeRemaining = "in \(hours)h \(minutes)m"
        }
    }
}

// MARK: - Preview

struct DeveloperModeView_Previews: PreviewProvider {
    static var previews: some View {
        DeveloperModeView()
    }
}
