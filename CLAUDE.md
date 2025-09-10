# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TimelyMeet is a SwiftUI-based macOS menu bar application for meeting notifications and calendar management.

## Development Commands

### Building and Running
```bash
# Open in Xcode
open TimelyMeet.xcodeproj

# Build from command line
xcodebuild -project TimelyMeet.xcodeproj -scheme TimelyMeet build

# Run tests
xcodebuild test -project TimelyMeet.xcodeproj -scheme TimelyMeet -destination 'platform=macOS'
```

### Testing
- **Unit Tests**: Located in `TimelyMeetTests/` using Swift Testing framework (@testable import TimelyMeet)
- **UI Tests**: Located in `TimelyMeetUITests/` using XCTest framework
- Run single test: Use Xcode's test navigator or command line with specific test methods

## Architecture

### App Structure
- **TimelyMeetApp.swift**: Main app with MenuBarExtra as primary interface, WindowGroup for main window, Settings window for macOS
- **AppModel**: Centralized service management and dependency injection using @MainActor
- **ContentView.swift**: NavigationSplitView-based main interface following Apple's patterns

### Service Architecture
The app uses a centralized service model with dependency injection:
- **DataManager**: Core Data persistence (shared singleton)
- **CalendarViewModel**: EventKit integration for calendar access
- **NotificationService/NotificationScheduler**: Local notification management
- **MenuBarService**: Menu bar UI and status updates
- **FullscreenNotificationService**: Custom notification overlays
- **VideoConferenceManager**: Meeting URL detection and joining
- **BackgroundSyncService**: Automatic calendar synchronization
- **LocalizationManager**: Multi-language support

### Key Technologies
- **SwiftUI**: Primary UI framework with MenuBarExtra for menu bar presence
- **EventKit**: Calendar and event access
- **Core Data**: Local data persistence
- **Swift Testing**: Modern testing framework for unit tests
- **XCTest**: UI testing framework

### Project Layout
```
TimelyMeet/
├── TimelyMeet/
│   ├── Services/           # Business logic services
│   ├── Views/              # SwiftUI views and components
│   ├── Models/             # Data models and ViewModels
│   ├── Utils/              # Utility functions and extensions
│   ├── Resources/          # Localization and assets
│   └── Assets.xcassets/    # App icons and images
├── TimelyMeetTests/        # Unit tests (Swift Testing)
└── TimelyMeetUITests/      # UI tests (XCTest)
```

## Instructions

1. Use context7 mcp for documentation
2. Add localization for all strings and UI elements, use readable id for localization purposes. Files with localization are to large, so dont try to read them all at once.
Ids for localization must use localized() method. For example - `GroupBox("supported_languages_title".localized())`
3. Use logger like (private let logger = Logger(subsystem: "org.romancha.timelymeet", category: "SomeCategory")) for logging purposes
