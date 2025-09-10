//
//  CalendarViewModelTests.swift
//  TimelyMeetTests
//
//  Created by Claude Code
//

import Testing
import EventKit
@testable import TimelyMeet

@MainActor
struct CalendarViewModelTests {
    
    @Test("Calendar view model initialization")
    func testCalendarViewModelInit() async throws {
        let viewModel = CalendarViewModel()
        
        #expect(viewModel.events.isEmpty)
        #expect(viewModel.calendars.isEmpty)
        #expect(!viewModel.isLoading)
        #expect(viewModel.authorizationStatus == .notDetermined ||
                viewModel.authorizationStatus == .authorized ||
                viewModel.authorizationStatus == .fullAccess ||
                viewModel.authorizationStatus == .denied)
    }
    
    @Test("Check authorization status updates correctly")
    func testCheckAuthorizationStatus() async throws {
        let viewModel = CalendarViewModel()
        let initialStatus = viewModel.authorizationStatus
        
        viewModel.checkAuthorizationStatus()
        
        // Status should remain consistent
        #expect(viewModel.authorizationStatus == initialStatus)
    }
    
    @Test("Video conference info extraction")
    func testVideoConferenceInfo() async throws {
        let viewModel = CalendarViewModel()
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.title = "Test Meeting"
        event.notes = "Join at https://zoom.us/j/1234567890"
        
        let videoInfo = viewModel.getVideoConferenceInfo(for: event)
        
        #expect(videoInfo != nil)
        #expect(videoInfo?.platform == .zoom)
        #expect(videoInfo?.url.absoluteString == "https://zoom.us/j/1234567890")
    }
    
    @Test("Video conference info extraction returns nil for no URL")
    func testVideoConferenceInfoNoURL() async throws {
        let viewModel = CalendarViewModel()
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.title = "Regular Meeting"
        event.location = "Conference Room A"
        
        let videoInfo = viewModel.getVideoConferenceInfo(for: event)
        
        #expect(videoInfo == nil)
    }
    
    @Test("Request calendar access handles permissions gracefully")
    func testRequestCalendarAccess() async throws {
        let viewModel = CalendarViewModel()
        let initialStatus = viewModel.authorizationStatus
        
        // This should not crash regardless of permission state
        await viewModel.requestCalendarAccess()
        
        // Status might change or remain the same depending on user interaction
        #expect(viewModel.authorizationStatus == initialStatus ||
                viewModel.authorizationStatus == .fullAccess ||
                viewModel.authorizationStatus == .denied)
    }
}
