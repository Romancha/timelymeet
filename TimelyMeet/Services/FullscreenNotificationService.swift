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

    enum WindowState: CustomStringConvertible {
        case showing
        case dismissing
        case dismissed

        var description: String {
            switch self {
            case .showing: return "showing"
            case .dismissing: return "dismissing"
            case .dismissed: return "dismissed"
            }
        }
    }

    private var notificationWindows: Set<NSWindow> = []
    private var windowStates: [NSWindow: WindowState] = [:]
    private var visibilityTimers: [NSWindow: DispatchSourceTimer] = [:]
    private var snoozeTimers: [DispatchSourceTimer] = []
    private var emergencyDismissObserver: NSObjectProtocol?

    private let soundService = CustomSoundService()
    private let themeService: NotificationThemeService
    private let logger = Logger(subsystem: "org.romancha.timelymeet", category: "FullscreenNotificationService")
    
    init(themeService: NotificationThemeService) {
        self.themeService = themeService
        // No special permissions required for overlay windows
        soundService.loadSelectedSound()
        // Ensure theme is loaded for developer tools
        _ = themeService.selectedTheme

        self.emergencyDismissObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("EmergencyDismissNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.forceDismissCurrentNotification()
            }
        }
    }

    deinit {
        // Clean up notification observer
        if let observer = emergencyDismissObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        // Cancel all timers
        for timer in snoozeTimers {
            timer.cancel()
        }

        for (_, timer) in visibilityTimers {
            timer.cancel()
        }
    }
    
    func showFullscreenNotification(for event: EKEvent, videoInfo: VideoConferenceInfo?) {
        let startTime = CFAbsoluteTimeGetCurrent()
        logger.info("Showing immediate fullscreen notification for: \(event.title ?? "Untitled Event")")

        // Cancel any existing notifications to prevent multiple windows
        // Use force dismiss (synchronous) instead of async to prevent race condition
        if let existingWindow = currentNotificationWindow,
           windowStates[existingWindow] == .showing {
            logger.warning("Force dismissing existing notification before showing new one")
            forceDismissCurrentNotification()
        }

        // Cancel all snooze timers
        cancelAllSnoozeTimers()

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
        windowStates[notificationWindow] = .showing
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
                guard let self = self else { return }
                self.logger.info("Join button pressed")

                // Cancel visibility timer immediately to prevent interference
                if let window = self.currentNotificationWindow {
                    self.cancelVisibilityTimer(for: window)
                }

                Task { @MainActor in
                    await self.dismissCurrentNotification()
                    
                    if let videoInfo = videoInfo {
                        do {
                            try await VideoConferenceManager().joinMeeting(url: videoInfo.url)
                            self.logger.info("Successfully joined meeting")
                        } catch {
                            self.logger.error("Failed to join meeting: \(error.localizedDescription)")
                        }
                    }
                }
            },
            onSnooze: { [weak self] option in
                guard let self = self else { return }
                self.logger.info("Snooze button pressed: \(option.displayName)")

                if let window = self.currentNotificationWindow {
                    self.cancelVisibilityTimer(for: window)
                }

                Task { @MainActor in
                    await self.snoozeCurrentNotification(for: event, option: option)
                }
            },
            onDismiss: { [weak self] in
                guard let self = self else { return }
                self.logger.info("Dismiss button pressed")

                if let window = self.currentNotificationWindow {
                    self.cancelVisibilityTimer(for: window)
                }

                Task { @MainActor in
                    await self.dismissCurrentNotification()
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
        logger.debug("Showing window immediately")

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
        timer.setEventHandler { [weak self] in
            guard let self = self else {
                timer.cancel()
                return
            }

            // Check if window is still in showing state
            guard attempts < 10,
                  self.notificationWindows.contains(window),
                  self.windowStates[window] == .showing else {
                self.logger.debug("Cancelling visibility timer - window no longer showing")
                timer.cancel()
                self.visibilityTimers.removeValue(forKey: window)
                return
            }

            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            attempts += 1
        }

        // Store timer reference and resume (order matters to avoid race condition)
        timer.resume()
        visibilityTimers[window] = timer

        // Clean up timer after 500ms
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.cancelVisibilityTimer(for: window)
        }
    }

    private func cancelVisibilityTimer(for window: NSWindow) {
        if let timer = visibilityTimers[window] {
            logger.debug("Cancelling visibility timer for window")
            timer.cancel()
            visibilityTimers.removeValue(forKey: window)  // Remove from map to release strong reference
        }
    }

    private func cancelAllSnoozeTimers() {
        logger.debug("Cancelling all snooze timers (count: \(self.snoozeTimers.count))")
        for timer in self.snoozeTimers {
            timer.cancel()
        }
        self.snoozeTimers.removeAll()
    }
    
    func dismissCurrentNotification() async {
        guard let window = currentNotificationWindow else {
            logger.debug("No current notification to dismiss")
            return
        }
        await dismissNotificationWindow(window)
    }

    private func dismissNotificationWindow(_ window: NSWindow) async {
        if let state = windowStates[window], state != .showing {
            logger.debug("Window already in state: \(state), skipping dismiss")
            return
        }

        logger.info("Dismissing notification window")
        windowStates[window] = .dismissing

        cancelVisibilityTimer(for: window)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            // Note: Both timeout and animation completion run on main queue (serial execution)
            // This ensures didComplete flag is thread-safe without atomics
            var didComplete = false

            // Set up timeout (2 seconds max for animation)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                if !didComplete {
                    self?.logger.warning("Dismiss animation timed out, forcing close")
                    didComplete = true
                    continuation.resume()
                }
            }

            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                context.completionHandler = {
                    if !didComplete {
                        didComplete = true
                        continuation.resume()
                    }
                }

                window.animator().alphaValue = 0
                window.animator().setFrame(window.frame.insetBy(dx: 25, dy: 25), display: true)
            })
        }

        // Remove window and cleanup all references to prevent memory leak
        window.orderOut(nil)
        notificationWindows.remove(window)
        windowStates.removeValue(forKey: window)  // Remove from state map to release strong reference

        if currentNotificationWindow == window {
            currentNotificationWindow = nil
        }

        logger.info("Notification window dismissed successfully")
    }

    func forceDismissCurrentNotification() {
        guard let window = currentNotificationWindow else {
            logger.debug("No current notification to force dismiss")
            return
        }

        logger.warning("Force dismissing notification window (emergency)")

        cancelVisibilityTimer(for: window)

        // Immediately close window and cleanup all references
        window.orderOut(nil)
        notificationWindows.remove(window)
        windowStates.removeValue(forKey: window)  // Remove from state map to release strong reference
        currentNotificationWindow = nil
    }
    
    private func snoozeCurrentNotification(for event: EKEvent, option: SnoozeOption) async {
        logger.info("Snoozing notification for \(option.displayName)")

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

        logger.debug("Scheduling snooze timer for \(snoozeSeconds) seconds")

        // Schedule another notification after snooze period using precise timer
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(deadline: .now() + .seconds(snoozeSeconds))

        timer.setEventHandler { [weak self] in
            guard let self = self else {
                timer.cancel()
                return
            }

            self.logger.info("Snooze timer fired, showing notification again")

            // Re-get event info in case it changed
            if let videoInfo = VideoConferenceManager().extractVideoConferenceInfo(from: event) {
                self.showFullscreenNotification(for: event, videoInfo: videoInfo)
            }

            // Remove from tracked timers
            if let index = self.snoozeTimers.firstIndex(where: { $0 === timer }) {
                self.snoozeTimers.remove(at: index)
            }
            timer.cancel()
        }

        // Track timer so it can be cancelled if needed
        snoozeTimers.append(timer)
        timer.resume()
    }
    
    func dismissAllNotifications() async {
        logger.info("Dismissing all notifications")

        // Cancel all timers
        cancelAllSnoozeTimers()

        let windows = Array(notificationWindows)
        for window in windows {
            cancelVisibilityTimer(for: window)
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

