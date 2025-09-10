
import Testing
import EventKit
@testable import TimelyMeet

@MainActor
struct VideoConferenceManagerTests {
    
    let manager = VideoConferenceManager()
    let calendarViewModel = CalendarViewModel()
    
    // MARK: - Enhanced Tests per Technical Specification
    
    @Test("Extract Zoom URL from event")
    func testExtractZoomURL() async throws {
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.title = "Daily Standup"
        event.notes = "Join Zoom Meeting https://zoom.us/j/1234567890"
        
        let videoInfo = manager.extractVideoConferenceInfo(from: event)
        
        #expect(videoInfo != nil)
        #expect(videoInfo?.platform == .zoom)
        #expect(videoInfo?.url.absoluteString == "https://zoom.us/j/1234567890")
        #expect(videoInfo?.displayName == "Join Zoom")
    }
    
    @Test("Extract Zoom URL with password")
    func testExtractZoomURLWithPassword() async throws {
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.notes = "Meeting: https://zoom.us/j/1234567890?pwd=abc123"
        
        let enhancedInfo = manager.extractEnhancedVideoConferenceInfo(from: event)
        
        #expect(enhancedInfo != nil)
        #expect(enhancedInfo?.platform == .zoom)
        #expect(enhancedInfo?.extractedParameters["pwd"] == "abc123")
        #expect(enhancedInfo?.extractedParameters["meetingId"] == "1234567890")
    }
    
    @Test("Zoom personal room forces web fallback")
    func testZoomPersonalRoomWebFallback() async throws {
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.notes = "My room: https://zoom.us/my/john.doe"
        
        let enhancedInfo = manager.extractEnhancedVideoConferenceInfo(from: event)
        
        #expect(enhancedInfo != nil)
        #expect(enhancedInfo?.platform == .zoom)
        #expect(enhancedInfo?.normalizedUrl.path.starts(with: "/my/") == true)
    }
    
    @Test("Extract Teams URL from event")
    func testExtractTeamsURL() async throws {
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.location = "https://teams.microsoft.com/l/meetup-join/19%3ameeting_abc123"
        
        let videoInfo = manager.extractVideoConferenceInfo(from: event)
        
        #expect(videoInfo != nil)
        #expect(videoInfo?.platform == .teams)
        #expect(videoInfo?.displayName == "Join Teams")
    }
    
    @Test("Extract Google Meet URL from event")
    func testExtractGoogleMeetURL() async throws {
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.notes = "Meeting details: https://meet.google.com/abc-defg-hij"
        
        let videoInfo = manager.extractVideoConferenceInfo(from: event)
        
        #expect(videoInfo != nil)
        #expect(videoInfo?.platform == .meet)
        #expect(videoInfo?.displayName == "Join Meet")
    }
    
    @Test("Google Meet has no deeplink per TS")
    func testGoogleMeetNoDeeplink() async throws {
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.notes = "https://meet.google.com/abc-defg-hij"
        
        let enhancedInfo = manager.extractEnhancedVideoConferenceInfo(from: event)
        
        #expect(enhancedInfo != nil)
        #expect(enhancedInfo?.platform == .meet)
        #expect(enhancedInfo?.config.hasDeeplink == false)
        #expect(enhancedInfo?.config.specialHandling.contains("universal_links_only") == true)
    }
    
    @Test("Extract Yandex Telemost URL from event")
    func testExtractTelermostURL() async throws {
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.notes = "Присоединяйтесь: https://telemost.yandex.ru/j/12345678901234567890"
        
        let videoInfo = manager.extractVideoConferenceInfo(from: event)
        
        #expect(videoInfo != nil)
        #expect(videoInfo?.platform == .telemost)
        #expect(videoInfo?.displayName == "Join Телемост")
    }
    
    @Test("Extract Yandex Telemost 360 URL from event")
    func testExtractTelemost360URL() async throws {
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.location = "https://telemost.360.yandex.ru/j/12345678901234567890"
        
        let videoInfo = manager.extractVideoConferenceInfo(from: event)
        
        #expect(videoInfo != nil)
        #expect(videoInfo?.platform == .telemost)
        #expect(videoInfo?.displayName == "Join Телемост")
    }
    
    @Test("Extract Dion URL from event")
    func testExtractDionURL() async throws {
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.title = "Встреча в Dion: https://dion.vc/room/abc123"
        
        let videoInfo = manager.extractVideoConferenceInfo(from: event)
        
        #expect(videoInfo != nil)
        #expect(videoInfo?.platform == .dion)
        #expect(videoInfo?.displayName == "Join Dion")
    }
    
    @Test("No video conference URL found")
    func testNoVideoConferenceURL() async throws {
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.title = "Regular Meeting"
        event.location = "Conference Room A"
        
        let videoInfo = manager.extractVideoConferenceInfo(from: event)
        
        #expect(videoInfo == nil)
    }
    
    @Test("Invalid URL should return nil")
    func testInvalidURL() async throws {
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.notes = "Invalid URL: https://suspicious-site.com/malicious"
        
        let videoInfo = manager.extractVideoConferenceInfo(from: event)
        
        #expect(videoInfo == nil)
    }
    
    @Test("Multiple URLs - should return first valid one")
    func testMultipleURLs() async throws {
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.notes = """
        Meeting details:
        Zoom: https://zoom.us/j/1111111111
        Teams backup: https://teams.microsoft.com/l/meetup-join/backup123
        """
        
        let videoInfo = manager.extractVideoConferenceInfo(from: event)
        
        #expect(videoInfo != nil)
        #expect(videoInfo?.platform == .zoom)
        #expect(videoInfo?.url.absoluteString == "https://zoom.us/j/1111111111")
    }
    
    @Test("Join meeting with valid URL doesn't crash")
    func testJoinMeetingValidURL() async throws {
        let url = URL(string: "https://zoom.us/j/1234567890")!
        
        // This should not crash - we're testing that the method handles the URL appropriately
        // In a real test environment, we would mock NSWorkspace.shared
        do {
            try await manager.joinMeeting(url: url)
        } catch {
            // Expected to fail in test environment, but shouldn't crash
            #expect(error != nil)
        }
    }
    
    // MARK: - Safe Links and URL Normalization Tests
    
    @Test("Microsoft Safe Links removal")
    func testMicrosoftSafeLinksRemoval() async throws {
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        let safeLink = "https://safelinks.protection.outlook.com/?url=https%3A//zoom.us/j/1234567890&data=abc123"
        event.notes = "Click here: \(safeLink)"
        
        let enhancedInfo = manager.extractEnhancedVideoConferenceInfo(from: event)
        
        #expect(enhancedInfo != nil)
        #expect(enhancedInfo?.platform == .zoom)
        #expect(enhancedInfo?.originalUrl.host?.contains("safelinks.protection.outlook.com") == true)
        #expect(enhancedInfo?.normalizedUrl.host?.contains("zoom.us") == true)
    }
    
    @Test("Tracking parameters removal")
    func testTrackingParametersRemoval() async throws {
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.notes = "https://meet.google.com/abc-defg-hij?utm_source=email&utm_campaign=meeting"
        
        let enhancedInfo = manager.extractEnhancedVideoConferenceInfo(from: event)
        
        #expect(enhancedInfo != nil)
        #expect(enhancedInfo?.normalizedUrl.query?.contains("utm_") == false)
    }
    
    // MARK: - Provider Configuration Tests
    
    @Test("Webex meetings use web-only per TS")
    func testWebexMeetingsWebOnly() async throws {
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.notes = "https://company.webex.com/meet/room123"
        
        let enhancedInfo = manager.extractEnhancedVideoConferenceInfo(from: event)
        
        #expect(enhancedInfo != nil)
        #expect(enhancedInfo?.platform == .webex)
        #expect(enhancedInfo?.config.hasDeeplink == false)
        #expect(enhancedInfo?.config.specialHandling.contains("meetings_web_only") == true)
    }
    
    @Test("Jitsi desktop deeplink conditional")
    func testJitsiDesktopDeeplink() async throws {
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.notes = "https://meet.jit.si/MyRoom"
        
        let enhancedInfo = manager.extractEnhancedVideoConferenceInfo(from: event)
        
        #expect(enhancedInfo != nil)
        #expect(enhancedInfo?.platform == .jitsi)
        #expect(enhancedInfo?.config.hasDeeplink == true)
        #expect(enhancedInfo?.config.specialHandling.contains("mobile_only_scheme") == true)
    }
    
    // MARK: - Browser Selection Tests
    
    @Test("Browser selection preferences")
    func testBrowserSelection() async throws {
        let preferences = VideoConferencePreferences()
        
        // Test default browser setting (uses recommended)
        #expect(preferences.browserFor(provider: .zoom) == .system) // Uses recommended default
        
        // Test provider-specific browser setting
        preferences.setBrowser(.firefox, for: .teams)
        #expect(preferences.browserFor(provider: .teams) == .firefox)
        #expect(preferences.browserFor(provider: .zoom) == .system) // Still uses recommended default
    }
    
    @Test("Join meeting with invalid URL throws error")
    func testJoinMeetingInvalidURL() async throws {
        let url = URL(string: "https://malicious-site.com/fake-meeting")!
        
        // Should throw an error due to URL validation
        do {
            try await manager.joinMeeting(url: url)
            #expect(false, "Should have thrown an error for invalid URL")
        } catch {
            // Expected behavior - should throw security validation error
            #expect(error != nil)
        }
    }
    
    // MARK: - Tests for new providers
    
    @Test("Extract Discord URL from event")
    func testExtractDiscordURL() async throws {
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.notes = "Join Discord: https://discord.gg/abcd1234"
        
        let videoInfo = manager.extractVideoConferenceInfo(from: event)
        
        #expect(videoInfo != nil)
        #expect(videoInfo?.platform == .discord)
        #expect(videoInfo?.displayName == "Join Discord")
    }
    
    @Test("Extract Slack URL from event")
    func testExtractSlackURL() async throws {
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.location = "https://app.slack.com/huddle/T1234567/C9876543"
        
        let videoInfo = manager.extractVideoConferenceInfo(from: event)
        
        #expect(videoInfo != nil)
        #expect(videoInfo?.platform == .slack)
        #expect(videoInfo?.displayName == "Join Slack")
    }
    
    @Test("Slack huddle deeplink generation")
    func testSlackHuddleDeeplink() async throws {
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.location = "https://app.slack.com/huddle/T1234567/C9876543"
        
        let enhancedInfo = manager.extractEnhancedVideoConferenceInfo(from: event)
        
        #expect(enhancedInfo != nil)
        #expect(enhancedInfo?.platform == .slack)
        #expect(enhancedInfo?.config.hasDeeplink == true)
        #expect(enhancedInfo?.config.deeplinkScheme == "slack")
    }
    
    @Test("Extract Webex URL from event")
    func testExtractWebexURL() async throws {
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.notes = "Meeting link: https://company.webex.com/meet/room123"
        
        let videoInfo = manager.extractVideoConferenceInfo(from: event)
        
        #expect(videoInfo != nil)
        #expect(videoInfo?.platform == .webex)
        #expect(videoInfo?.displayName == "Join Webex")
    }
    
    @Test("Extract Jitsi URL from event")
    func testExtractJitsiURL() async throws {
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.title = "Open Source Meeting: https://meet.jit.si/MyMeetingRoom"
        
        let videoInfo = manager.extractVideoConferenceInfo(from: event)
        
        #expect(videoInfo != nil)
        #expect(videoInfo?.platform == .jitsi)
        #expect(videoInfo?.displayName == "Join Jitsi")
    }
    
    @Test("Extract WhatsApp URL from event")
    func testExtractWhatsAppURL() async throws {
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.notes = "Group call: https://chat.whatsapp.com/invite/abc123xyz"
        
        let videoInfo = manager.extractVideoConferenceInfo(from: event)
        
        #expect(videoInfo != nil)
        #expect(videoInfo?.platform == .whatsapp)
        #expect(videoInfo?.displayName == "Join WhatsApp")
    }
    
    @Test("Extract Telegram URL from event")
    func testExtractTelegramURL() async throws {
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.location = "https://t.me/joinchat/meeting123"
        
        let videoInfo = manager.extractVideoConferenceInfo(from: event)
        
        #expect(videoInfo != nil)
        #expect(videoInfo?.platform == .telegram)
        #expect(videoInfo?.displayName == "Join Telegram")
    }
    
    @Test("Extract Skype URL from event")
    func testExtractSkypeURL() async throws {
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.notes = "Video call: https://join.skype.com/abc123def456"
        
        let videoInfo = manager.extractVideoConferenceInfo(from: event)
        
        #expect(videoInfo != nil)
        #expect(videoInfo?.platform == .skype)
        #expect(videoInfo?.displayName == "Join Skype")
    }
    
    @Test("Extract Whereby URL from event")
    func testExtractWherebyURL() async throws {
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.title = "Quick meeting: https://whereby.com/my-room"
        
        let videoInfo = manager.extractVideoConferenceInfo(from: event)
        
        #expect(videoInfo != nil)
        #expect(videoInfo?.platform == .whereby)
        #expect(videoInfo?.displayName == "Join Whereby")
    }
    
    @Test("Extract FaceTime URL from event")
    func testExtractFaceTimeURL() async throws {
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.location = "https://facetime.apple.com/join#v=1&p=abc123&k=xyz789"
        
        let videoInfo = manager.extractVideoConferenceInfo(from: event)
        
        #expect(videoInfo != nil)
        #expect(videoInfo?.platform == .facetime)
        #expect(videoInfo?.displayName == "Join FaceTime")
    }
    
    @Test("FaceTime system handler configuration")
    func testFaceTimeSystemHandler() async throws {
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.notes = "https://facetime.apple.com/join#v=1&p=abc123"
        
        let enhancedInfo = manager.extractEnhancedVideoConferenceInfo(from: event)
        
        #expect(enhancedInfo != nil)
        #expect(enhancedInfo?.platform == .facetime)
        #expect(enhancedInfo?.config.specialHandling.contains("system_handler") == true)
    }
}