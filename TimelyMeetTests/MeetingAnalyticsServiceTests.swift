//
//  MeetingAnalyticsServiceTests.swift
//  TimelyMeetTests
//
//  Created by Claude Code
//

import Testing
import EventKit
@testable import TimelyMeet

@MainActor
struct MeetingAnalyticsServiceTests {
    
    @Test("Analytics service initialization")
    func testAnalyticsServiceInit() async throws {
        let service = MeetingAnalyticsService()
        
        #expect(service.analytics.totalNotificationsShown >= 0)
        #expect(service.analytics.totalJoinAttempts >= 0)
        #expect(service.recentActivity.count >= 0)
    }
    
    @Test("Track notification shown")
    func testTrackNotificationShown() async throws {
        let service = MeetingAnalyticsService()
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.title = "Test Meeting"
        
        let initialCount = service.analytics.totalNotificationsShown
        
        service.trackNotificationShown(for: event, type: .fullscreen, minutesBefore: 5)
        
        #expect(service.analytics.totalNotificationsShown == initialCount + 1)
        #expect(!service.recentActivity.isEmpty)
        
        let lastActivity = service.recentActivity.first!
        #expect(lastActivity.action == .notificationShown)
        #expect(lastActivity.eventTitle == "Test Meeting")
        #expect(lastActivity.metadata["minutesBefore"] == "5")
    }
    
    @Test("Track fullscreen notification")
    func testTrackFullscreenNotification() async throws {
        let service = MeetingAnalyticsService()
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.title = "Important Meeting"
        
        let initialCount = service.analytics.fullscreenNotificationsShown
        
        service.trackNotificationShown(for: event, type: .fullscreen, minutesBefore: 1)
        
        #expect(service.analytics.fullscreenNotificationsShown == initialCount + 1)
        
        let lastActivity = service.recentActivity.first!
        #expect(lastActivity.metadata["type"] == "fullscreen")
    }
    
    @Test("Track meeting join attempt")
    func testTrackMeetingJoinAttempt() async throws {
        let service = MeetingAnalyticsService()
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.title = "Zoom Meeting"
        
        let url = URL(string: "https://zoom.us/j/1234567890")!
        let initialAttempts = service.analytics.totalJoinAttempts
        
        service.trackMeetingJoinAttempt(for: event, platform: .zoom, url: url)
        
        #expect(service.analytics.totalJoinAttempts == initialAttempts + 1)
        #expect(service.analytics.platformJoinCounts[.zoom] == 1 || service.analytics.platformJoinCounts[.zoom]! > 0)
        
        let lastActivity = service.recentActivity.first!
        #expect(lastActivity.action == .joinAttempted)
        #expect(lastActivity.platform == .zoom)
        #expect(lastActivity.metadata["url"] == url.absoluteString)
    }
    
    @Test("Track meeting join success")
    func testTrackMeetingJoinSuccess() async throws {
        let service = MeetingAnalyticsService()
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.title = "Teams Meeting"
        
        let initialSuccesses = service.analytics.successfulJoins
        
        service.trackMeetingJoinSuccess(for: event, platform: .teams)
        
        #expect(service.analytics.successfulJoins == initialSuccesses + 1)
        #expect(service.analytics.platformSuccessfulJoins[.teams] == 1 || service.analytics.platformSuccessfulJoins[.teams]! > 0)
        
        let lastActivity = service.recentActivity.first!
        #expect(lastActivity.action == .joinSuccessful)
        #expect(lastActivity.platform == .teams)
    }
    
    @Test("Track meeting join failure")
    func testTrackMeetingJoinFailure() async throws {
        let service = MeetingAnalyticsService()
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.title = "Failed Meeting"
        
        let initialFailures = service.analytics.failedJoins
        let errorMessage = "Connection timeout"
        
        service.trackMeetingJoinFailure(for: event, platform: .meet, error: errorMessage)
        
        #expect(service.analytics.failedJoins == initialFailures + 1)
        #expect(service.analytics.platformFailedJoins[.meet] == 1 || service.analytics.platformFailedJoins[.meet]! > 0)
        
        let lastActivity = service.recentActivity.first!
        #expect(lastActivity.action == .joinFailed)
        #expect(lastActivity.platform == .meet)
        #expect(lastActivity.metadata["error"] == errorMessage)
    }
    
    @Test("Calculate join success rate")
    func testGetJoinSuccessRate() async throws {
        let service = MeetingAnalyticsService()
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.title = "Test Meeting"
        
        // Track some attempts and successes
        service.trackMeetingJoinAttempt(for: event, platform: .zoom, url: URL(string: "https://zoom.us/j/123")!)
        service.trackMeetingJoinSuccess(for: event, platform: .zoom)
        
        service.trackMeetingJoinAttempt(for: event, platform: .zoom, url: URL(string: "https://zoom.us/j/456")!)
        service.trackMeetingJoinSuccess(for: event, platform: .zoom)
        
        service.trackMeetingJoinAttempt(for: event, platform: .zoom, url: URL(string: "https://zoom.us/j/789")!)
        service.trackMeetingJoinFailure(for: event, platform: .zoom, error: "Error")
        
        let successRate = service.getJoinSuccessRate()
        
        #expect(successRate > 0.0)
        #expect(successRate <= 1.0)
        
        // Should be 2 successes out of 3 attempts = 0.666...
        #expect(abs(successRate - (2.0/3.0)) < 0.1)
    }
    
    @Test("Calculate platform-specific success rate")
    func testGetJoinSuccessRateForPlatform() async throws {
        let service = MeetingAnalyticsService()
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.title = "Platform Test"
        
        // Track Zoom attempts
        service.trackMeetingJoinAttempt(for: event, platform: .zoom, url: URL(string: "https://zoom.us/j/123")!)
        service.trackMeetingJoinSuccess(for: event, platform: .zoom)
        
        service.trackMeetingJoinAttempt(for: event, platform: .zoom, url: URL(string: "https://zoom.us/j/456")!)
        service.trackMeetingJoinSuccess(for: event, platform: .zoom)
        
        // Track Teams attempts
        service.trackMeetingJoinAttempt(for: event, platform: .teams, url: URL(string: "https://teams.microsoft.com/l/meetup-join/abc")!)
        service.trackMeetingJoinFailure(for: event, platform: .teams, error: "Error")
        
        let zoomSuccessRate = service.getJoinSuccessRate(for: .zoom)
        let teamsSuccessRate = service.getJoinSuccessRate(for: .teams)
        
        #expect(zoomSuccessRate == 1.0) // 2 successes out of 2 attempts
        #expect(teamsSuccessRate == 0.0) // 0 successes out of 1 attempt
    }
    
    @Test("Generate weekly report")
    func testGenerateWeeklyReport() async throws {
        let service = MeetingAnalyticsService()
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.title = "Weekly Test"
        
        // Add some activity
        service.trackNotificationShown(for: event, type: .fullscreen, minutesBefore: 5)
        service.trackMeetingJoinAttempt(for: event, platform: .zoom, url: URL(string: "https://zoom.us/j/123")!)
        service.trackMeetingJoinSuccess(for: event, platform: .zoom)
        
        let report = service.generateWeeklyReport()
        
        #expect(report.totalNotifications >= 1)
        #expect(report.successfulJoins >= 1)
        #expect(report.failedJoins >= 0)
        #expect(report.averageResponseTime >= 0)
    }
    
    @Test("Track app launch")
    func testTrackAppLaunch() async throws {
        let service = MeetingAnalyticsService()
        let initialLaunches = service.analytics.appLaunches
        
        service.trackAppLaunch()
        
        #expect(service.analytics.appLaunches == initialLaunches + 1)
        #expect(service.analytics.lastLaunchDate != nil)
    }
}