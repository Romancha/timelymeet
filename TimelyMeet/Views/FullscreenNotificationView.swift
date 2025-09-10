//
//  FullscreenNotificationView.swift
//  TimelyMeet
//
//
//

import SwiftUI
import EventKit
import AppKit

struct FullscreenNotificationView: View {
    let event: EKEvent
    let videoInfo: VideoConferenceInfo?
    let theme: NotificationTheme
    let onJoin: () -> Void
    let onSnooze: (SnoozeOption) -> Void
    let onDismiss: () -> Void
    
    @State private var isAnimating = false
    @State private var pulseAnimation = false
    @State private var showSnoozeOptions = false
    @State private var customSnoozeMinutes = ""
    @State private var keyDownMonitor: Any?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Full screen semi-transparent background with theme support
                Rectangle()
                    .fill(Color(theme.backgroundColor).opacity(0.85))
                    .ignoresSafeArea(.all)
                
                // Main notification card
                VStack(spacing: 0) {
                    // Top section with current time and dismiss
                    topBar
                    
                    // Main content area
                    Spacer()
                    
                    // Central meeting information
                    centralContent
                        .frame(maxWidth: min(geometry.size.width * 0.8, 800))
                    
                    Spacer()
                    
                    // Bottom action buttons
                    bottomActions
                    
                    Spacer(minLength: 40)
                }
                .padding(40)
            }
        }
        .background(Color.clear)
        .scaleEffect(isAnimating ? 1.0 : 0.95)
        .opacity(isAnimating ? 1.0 : 0.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isAnimating)
        .onAppear {
            isAnimating = true
        }
        .sheet(isPresented: $showSnoozeOptions) {
            CustomSnoozeView { option in
                showSnoozeOptions = false
                onSnooze(option)
            }
        }
        // Global keyboard shortcuts handled by the service
        .onAppear {
            setupGlobalHotkeys()
        }
        .onDisappear {
            cleanupGlobalHotkeys()
        }
    }
    
    private var topBar: some View {
        HStack {
            // Current time
            Text(Date().formatted(date: .abbreviated, time: .shortened))
                .font(.system(size: 18, weight: .medium, design: .monospaced))
                .foregroundColor(Color(theme.primaryTextColor).opacity(0.9))
            
            Spacer()
            
            // Close button
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color(theme.primaryTextColor).opacity(0.7))
            }
            .buttonStyle(.plain)
        }
    }
    
    private var centralContent: some View {
        VStack(spacing: 40) {
            // Urgency indicator and title
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.urgentAmber)
                        .frame(width: 16, height: 16)
                        .scaleEffect(pulseAnimation ? 1.3 : 1.0)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulseAnimation)
                        .onAppear { pulseAnimation = true }
                    
                    Text("meeting_starting_soon".localized())
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.urgentAmber)
                        .tracking(2)
                }
                
                // Time remaining (large)
                TimeUntilMeetingView(startDate: event.startDate, isFullscreen: true)
            }
            
            // Meeting title (prominent)
            Text(event.title ?? "untitled_meeting".localized())
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(Color(theme.primaryTextColor))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
            
            // Meeting details grid
            meetingDetailsGrid
        }
    }
    
    private var meetingDetailsGrid: some View {
        HStack(spacing: 60) {
            // Left column
            VStack(alignment: .leading, spacing: 20) {
                DetailRow(
                    icon: "clock",
                    title: "meeting_time_label".localized(),
                    content: formatMeetingTime(),
                    theme: theme
                )
                
                if let attendees = event.attendees, attendees.count > 1 {
                    DetailRow(
                        icon: "person.2",
                        title: "meeting_attendees_label".localized(),
                        content: String(format: "attendees_count".localized(), attendees.count),
                        theme: theme
                    )
                }
            }
            
            // Right column
            VStack(alignment: .leading, spacing: 20) {
                DetailRow(
                    icon: "calendar",
                    title: "meeting_calendar_label".localized(),
                    content: event.calendar?.title ?? "unknown".localized(),
                    color: event.calendar?.cgColor,
                    theme: theme
                )
                
                if let location = event.location, !location.isEmpty {
                    DetailRow(
                        icon: "location",
                        title: "meeting_location_label".localized(),
                        content: location,
                        theme: theme
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var bottomActions: some View {
        HStack(spacing: 24) {
            // Dismiss button
            ActionButton(
                title: "dismiss_button".localized(),
                icon: "xmark",
                color: .gray,
                action: onDismiss
            )
            
            // Quick Snooze button with dropdown menu
            SnoozeMenuButton(onSnooze: onSnooze, showCustomOptions: $showSnoozeOptions)
            
            // Join meeting button (primary)
            if let videoInfo = videoInfo {
                ActionButton(
                    title: videoInfo.displayName,
                    icon: videoInfo.platform.iconName,
                    color: .blue,
                    isPrimary: true,
                    action: onJoin
                )
            }
        }
    }
    
    private func formatMeetingTime() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        var timeStr = formatter.string(from: event.startDate)
        if let endDate = event.endDate {
            timeStr += " - " + formatter.string(from: endDate)
        }
        return timeStr
    }
    
    // MARK: - Global Hotkey Management
    
    private func setupGlobalHotkeys() {
        // Clear any existing monitor first
        cleanupGlobalHotkeys()
        
        // Set up local key event monitor for the fullscreen window
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let keyCode = event.keyCode
            
            // Handle different key presses
            switch keyCode {
            case 53: // ESC key
                onDismiss()
                return nil // Consume the event
                
            case 36: // Return key
                if videoInfo != nil {
                    onJoin()
                }
                return nil // Consume the event
                
            case 1: // S key
                onSnooze(.threeMinutes)
                return nil // Consume the event
                
            default:
                return event // Let other keys through
            }
        }
    }
    
    private func cleanupGlobalHotkeys() {
        if let monitor = keyDownMonitor {
            NSEvent.removeMonitor(monitor)
            keyDownMonitor = nil
        }
    }
}

struct TimeUntilMeetingView: View {
    let startDate: Date
    let isFullscreen: Bool
    @State private var timeRemaining: String = ""
    @State private var timer: Timer?
    
    init(startDate: Date, isFullscreen: Bool = false) {
        self.startDate = startDate
        self.isFullscreen = isFullscreen
    }
    
    var body: some View {
        Text(timeRemaining)
            .font(isFullscreen ? .system(size: 72, weight: .bold, design: .monospaced) : .subheadline)
            .fontWeight(isFullscreen ? .bold : .medium)
            .foregroundColor(timeRemaining.contains("OVERDUE") ? .urgentRed : .urgentAmber)
            .multilineTextAlignment(.center)
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
        let now = Date()
        let timeInterval = startDate.timeIntervalSince(now)
        
        if timeInterval <= 0 {
            // Meeting is overdue - show how much time has passed
            let overdueInterval = abs(timeInterval)
            if overdueInterval < 60 {
                timeRemaining = isFullscreen ? "OVERDUE \(Int(overdueInterval))s" : "overdue \(Int(overdueInterval))s"
            } else if overdueInterval < 3600 {
                let minutes = Int(overdueInterval / 60)
                let seconds = Int(overdueInterval.truncatingRemainder(dividingBy: 60))
                timeRemaining = isFullscreen ? "OVERDUE \(minutes):\(String(format: "%02d", seconds))" : "overdue \(minutes)m"
            } else {
                let hours = Int(overdueInterval / 3600)
                let minutes = Int((overdueInterval.truncatingRemainder(dividingBy: 3600)) / 60)
                timeRemaining = isFullscreen ? "OVERDUE \(hours):\(String(format: "%02d", minutes))" : "overdue \(hours)h \(minutes)m"
            }
            // Continue timer for overdue counter
        } else if timeInterval < 60 {
            timeRemaining = "\(Int(timeInterval)) SECONDS"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            let seconds = Int(timeInterval.truncatingRemainder(dividingBy: 60))
            timeRemaining = isFullscreen ? "\(minutes):\(String(format: "%02d", seconds))" : "in \(minutes)m"
        } else {
            let hours = Int(timeInterval / 3600)
            let minutes = Int((timeInterval.truncatingRemainder(dividingBy: 3600)) / 60)
            timeRemaining = isFullscreen ? "\(hours):\(String(format: "%02d", minutes)):00" : "in \(hours)h \(minutes)m"
        }
    }
}

// MARK: - Supporting Views

struct DetailRow: View {
    let icon: String
    let title: String
    let content: String
    let color: CGColor?
    let theme: NotificationTheme
    
    init(icon: String, title: String, content: String, color: CGColor? = nil, theme: NotificationTheme) {
        self.icon = icon
        self.title = title
        self.content = content
        self.color = color
        self.theme = theme
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(theme == .classic ? Color.white.opacity(0.7) : Color(NSColor.secondaryLabelColor))
                
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(theme == .classic ? Color.white.opacity(0.7) : Color(NSColor.secondaryLabelColor))
                    .tracking(1)
            }
            
            HStack(spacing: 8) {
                if let color = color {
                    Circle()
                        .fill(Color(color))
                        .frame(width: 10, height: 10)
                }
                
                Text(content)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(theme == .classic ? Color.white : Color(NSColor.labelColor))
            }
        }
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let isPrimary: Bool
    let action: () -> Void
    
    init(title: String, icon: String, color: Color, isPrimary: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.color = color
        self.isPrimary = isPrimary
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(isPrimary ? .white : color)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isPrimary ? color : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(color, lineWidth: isPrimary ? 0 : 2)
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(1.0)
        .animation(.easeInOut(duration: 0.1), value: isPrimary)
    }
}

// MARK: - Snooze Options

enum SnoozeOption {
    case oneMinute
    case threeMinutes
    case fiveMinutes
    case untilMeetingTime
    case custom(minutes: Int)
    
    var displayName: String {
        switch self {
        case .oneMinute: return "1 minute"
        case .threeMinutes: return "3 minutes"
        case .fiveMinutes: return "5 minutes"
        case .untilMeetingTime: return "Until meeting time"
        case .custom(let minutes): return "\(minutes) minutes"
        }
    }
    
    var seconds: Int {
        switch self {
        case .oneMinute: return 60
        case .threeMinutes: return 180
        case .fiveMinutes: return 300
        case .untilMeetingTime: return 0 // Special case - handle in service
        case .custom(let minutes): return minutes * 60
        }
    }
}

struct CustomSnoozeView: View {
    let onSelect: (SnoozeOption) -> Void
    @State private var customMinutes = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            Text("custom_snooze_time".localized())
                .font(.title2)
                .fontWeight(.bold)
            
            HStack(spacing: 12) {
                Text("remind_me_in".localized())
                    .font(.headline)
                
                TextField("5", text: $customMinutes)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .onSubmit {
                        applyCustomSnooze()
                    }
                
                Text("minutes".localized())
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 16) {
                Button("cancel".localized()) {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("apply_button".localized()) {
                    applyCustomSnooze()
                }
                .buttonStyle(.borderedProminent)
                .disabled(customMinutes.isEmpty || Int(customMinutes) == nil || Int(customMinutes) ?? 0 <= 0)
                .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(32)
        .frame(width: 320)
        .onAppear {
            customMinutes = "5" // Default value
        }
    }
    
    private func applyCustomSnooze() {
        if let minutes = Int(customMinutes), minutes > 0 {
            onSelect(.custom(minutes: minutes))
        }
    }
}



#Preview {
    let eventStore = EKEventStore()
    let sampleEvent = EKEvent(eventStore: eventStore)
    sampleEvent.title = "Daily Standup Meeting - Discussing Sprint Progress and Planning"
    sampleEvent.startDate = Date().addingTimeInterval(300) // 5 minutes from now
    sampleEvent.endDate = sampleEvent.startDate.addingTimeInterval(1800) // 30 minutes duration
    sampleEvent.location = "Conference Room A"
    
    let sampleCalendar = EKCalendar(for: .event, eventStore: eventStore)
    sampleCalendar.title = "Work Calendar"
    sampleCalendar.cgColor = NSColor.systemGreen.cgColor
    sampleEvent.calendar = sampleCalendar
    
    let videoInfo = VideoConferenceInfo(
        platform: .zoom,
        url: URL(string: "https://zoom.us/j/123456789")!,
        displayName: "Join Zoom"
    )
    
    return FullscreenNotificationView(
        event: sampleEvent,
        videoInfo: videoInfo,
        theme: .system,
        onJoin: { },
        onSnooze: { option in },
        onDismiss: { }
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
}

struct SnoozeMenuButton: View {
    let onSnooze: (SnoozeOption) -> Void
    @Binding var showCustomOptions: Bool
    
    var body: some View {
        Menu {
            Button("snooze_three_min".localized()) {
                onSnooze(.threeMinutes)
            }
            
            Divider()
            
            Button("snooze_one_min".localized()) {
                onSnooze(.oneMinute)
            }
            
            Button("snooze_five_min".localized()) {
                onSnooze(.custom(minutes: 5))
            }
            
            Button("snooze_until_meeting_time".localized()) {
                onSnooze(.untilMeetingTime)
            }
            
            Divider()
            
            Button("custom_snooze_time".localized()) {
                showCustomOptions = true
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.2.circlepath")
                    .font(.system(size: 20, weight: .semibold))
                Text("snooze_three_min".localized())
                    .font(.system(size: 18, weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .opacity(0.7)
            }
            .foregroundStyle(.orange)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
        } primaryAction: {
            onSnooze(.threeMinutes)
        }
        .buttonStyle(SnoozeButtonStyle())
        .fixedSize()
    }
}

// Custom button style to match the other action buttons
struct SnoozeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange, lineWidth: 2)
                    .fill(Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Color Extensions

extension Color {
    // Warm amber color for urgent notifications - attention-grabbing but not aggressive
    static let urgentAmber = Color(red: 1.0, green: 0.75, blue: 0.0) // #FFC000
    
    // Muted red for overdue items - more serious but not harsh
    static let urgentRed = Color(red: 0.9, green: 0.3, blue: 0.3) // #E64D4D
}
