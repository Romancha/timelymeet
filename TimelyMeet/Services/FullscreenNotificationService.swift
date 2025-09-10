//
//  FullscreenNotificationService.swift
//  TimelyMeet
//
//  
//

import SwiftUI
import AppKit
import EventKit
import OSLog

@MainActor
class FullscreenNotificationService: ObservableObject {
    @Published var currentNotificationWindow: NSWindow?
    
    private var notificationWindows: Set<NSWindow> = []
    private let soundService = CustomSoundService()
    private let themeService: NotificationThemeService
    private let logger = Logger(subsystem: "org.romancha.timelymeet", category: "FullscreenNotificationService")
    
    init(themeService: NotificationThemeService) {
        self.themeService = themeService
        // No special permissions required for overlay windows
        soundService.loadSelectedSound()
        // Ensure theme is loaded for developer tools
        _ = themeService.selectedTheme
    }
    
    func showFullscreenNotification(for event: EKEvent, videoInfo: VideoConferenceInfo?) {
        let startTime = CFAbsoluteTimeGetCurrent()
        logger.info("Showing immediate fullscreen notification for: \(event.title ?? "Untitled Event")")
        
        // Refresh theme settings to ensure we have the latest theme
        // This is important for developer tools and settings changes
        Task { @MainActor in
            self.themeService.objectWillChange.send()
        }
        
        // Play notification sound from settings
        soundService.playNotificationSound(soundService.selectedSound)
        
        // Create fullscreen notification window
        let notificationWindow = createNotificationWindow(for: event, videoInfo: videoInfo)
        notificationWindows.insert(notificationWindow)
        currentNotificationWindow = notificationWindow
        
        // Show immediately without animation delays
        showWindowImmediately(notificationWindow)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        logger.info("Fullscreen notification displayed in \((endTime - startTime) * 1000) ms")
    }
    
    private func createNotificationWindow(for event: EKEvent, videoInfo: VideoConferenceInfo?) -> NSWindow {
        // Create the SwiftUI view for notification content
        let notificationView = FullscreenNotificationView(
            event: event,
            videoInfo: videoInfo,
            theme: themeService.selectedTheme,
            onJoin: { [weak self] in
                Task { @MainActor in
                    if let videoInfo = videoInfo {
                        try? await VideoConferenceManager().joinMeeting(url: videoInfo.url)
                    }
                    await self?.dismissCurrentNotification()
                }
            },
            onSnooze: { [weak self] option in
                Task { @MainActor in
                    await self?.snoozeCurrentNotification(for: event, option: option)
                }
            },
            onDismiss: { [weak self] in
                Task { @MainActor in
                    await self?.dismissCurrentNotification()
                }
            }
        )
        
        // Create hosting view
        let hostingView = NSHostingView(rootView: notificationView)
        
        // Get main screen dimensions for full screen coverage
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let screenFrame = screen.frame
        
        // Create a full-screen borderless window
        let window = NSWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // Configure window for fullscreen overlay
        window.contentView = hostingView
        window.backgroundColor = NSColor.black.withAlphaComponent(0.4) // Semi-transparent dark overlay
        window.isOpaque = false
        window.hasShadow = false
        
        // Critical settings for fullscreen overlay behavior
        // Use the highest possible window level to ensure visibility above all apps
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)) + 1)
        
        // Collection behavior for spaces and fullscreen compatibility
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary
        ]
        
        // Window behavior settings
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true
        window.hidesOnDeactivate = false
        
        // Set the window frame to cover the entire screen
        window.setFrame(screenFrame, display: true)
        
        return window
    }
    
    private func showWindowImmediately(_ window: NSWindow) {
        // Show window at full opacity immediately - no animation delays
        window.alphaValue = 1.0
        
        // Critical: Use orderFrontRegardless for overlay windows to ensure they appear above all content
        window.orderFrontRegardless()
        
        // Make the window key to capture keyboard input and focus
        window.makeKeyAndOrderFront(nil)
        
        // Additional focus enforcement for fullscreen overlays
        NSApp.activate(ignoringOtherApps: true)
        
        // Force window to stay on top for critical notifications
        // Use a high-frequency timer for the first 500ms to override any fullscreen apps
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(50)) // Every 50ms
        
        var attempts = 0
        timer.setEventHandler {
            guard attempts < 10 && self.notificationWindows.contains(window) else {
                timer.cancel()
                return
            }
            
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            attempts += 1
        }
        
        timer.resume()
        
        // Clean up timer after 500ms
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            timer.cancel()
        }
    }
    
    func dismissCurrentNotification() async {
        guard let window = currentNotificationWindow else { return }
        await dismissNotificationWindow(window)
    }
    
    private func dismissNotificationWindow(_ window: NSWindow) async {
        // Animate window out
        await withCheckedContinuation { continuation in
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                context.completionHandler = { continuation.resume() }
                
                window.animator().alphaValue = 0
                window.animator().setFrame(window.frame.insetBy(dx: 25, dy: 25), display: true)
            })
        }
        
        // Remove window
        window.orderOut(nil)
        notificationWindows.remove(window)
        
        if currentNotificationWindow == window {
            currentNotificationWindow = nil
        }
    }
    
    private func snoozeCurrentNotification(for event: EKEvent, option: SnoozeOption) async {
        await dismissCurrentNotification()
        
        let snoozeSeconds: Int
        switch option {
        case .untilMeetingTime:
            // Calculate time until meeting starts minus 30 seconds for alert
            let timeUntilMeeting = event.startDate.timeIntervalSinceNow
            snoozeSeconds = max(Int(timeUntilMeeting) - 30, 10) // At least 10 seconds
        default:
            snoozeSeconds = option.seconds
        }
        
        // Schedule another notification after snooze period using precise timer
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(deadline: .now() + .seconds(snoozeSeconds))
        
        timer.setEventHandler {
            // Re-get event info in case it changed
            if let videoInfo = VideoConferenceManager().extractVideoConferenceInfo(from: event) {
                self.showFullscreenNotification(for: event, videoInfo: videoInfo)
            }
            timer.cancel()
        }
        
        timer.resume()
    }
    
    func dismissAllNotifications() async {
        let windows = Array(notificationWindows)
        for window in windows {
            await dismissNotificationWindow(window)
        }
    }
    
    // Debug method to test fullscreen notifications
    func testFullscreenNotification(for conferenceUrl: String) {
        // Play notification sound from settings
        soundService.playNotificationSound(soundService.selectedSound)
        
        let eventStore = EKEventStore()
        let testEvent = EKEvent(eventStore: eventStore)
        testEvent.title = "Software Engineering Meeting"
        testEvent.startDate = Date().addingTimeInterval(120)
        testEvent.endDate = Date().addingTimeInterval(1800)
        testEvent.notes = "This is a test fullscreen notification.\n\nJoin Zoom Meeting:\nhttps://zoom.us/j/1234567890"
        
        // Create a test calendar to avoid nil calendar issues
        let testCalendar = EKCalendar(for: .event, eventStore: eventStore)
        testCalendar.title = "Working Calendar"
        testCalendar.cgColor = NSColor.systemBlue.cgColor
        testEvent.calendar = testCalendar
        
        let testVideoInfo = VideoConferenceInfo(
            platform: .zoom,
            url: URL(string: conferenceUrl)!,
            displayName: "Join Zoom"
        )
        
        showFullscreenNotification(for: testEvent, videoInfo: testVideoInfo)
    }
}

