# TimelyMeet

<div align="center">

<!-- App Icon -->
<img src="TimelyMeet/Assets.xcassets/AppIcon.appiconset/AppIcon-128.png" alt="TimelyMeet Icon" width="128" height="128">

**Meeting Notifications for macOS**

Stay timely. Never miss a meet.

<!-- App Store Badge -->
[![Download on the App Store](https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg)](https://apps.apple.com/app/timelymeet/id6751949087)

![macOS](https://img.shields.io/badge/macOS-15.0+-blue?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.0+-orange?logo=swift)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Framework-blue)
![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)]

<div align="center">
<img src="docs/screenshot-main.png" alt="TimelyMeet Main Interface">
</div>

</div>

## ✨ Features

🚨 **Fullscreen Alerts** - Beautiful fullscreen notifications that grab your attention

⚡ **Fast join to conference** - One-click joining of video conferences with smart URL detection

🔔 **Adjustable notifications** - Customizable reminder times and notification sounds for your meetings

📊 **Meeting info in menu bar** - Always accessible from your menu bar with quick meeting overview

⌨️ **Keyboard Shortcuts** - ESC to dismiss, Enter to join meetings, S to snooze (3min). Hold snooze button for custom
time options

💎 **Completely Free** - No subscriptions, no hidden fees - all features are free

🔒 **Complete Privacy: We do not collect or store any user data** - Your calendar data stays private and secure on your
device

## 🚀 Getting Started

### Requirements

- macOS 15.0 or later
- Calendar access permissions

### Installation

#### From App Store (Recommended)

[![Download on the App Store](https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg)](https://apps.apple.com/app/timelymeet/id6751949087)

#### Building from Source

```bash
# Clone the repository
git clone https://github.com/romancha/TimelyMeet.git
cd TimelyMeet

# Open in Xcode
open TimelyMeet.xcodeproj

# Build and run
⌘ + R
```

## 🛠 Development

### Architecture

- **SwiftUI**: Modern declarative UI framework
- **EventKit**: Calendar and event access
- **Core Data**: Local data persistence

### Project Structure

```
TimelyMeet/
├── Services/           # Business logic services
├── Views/              # SwiftUI views and components
├── Models/             # Data models and ViewModels
├── Utils/              # Utility functions and extensions
└── Resources/          # Localization and assets
```

### Development Commands

```bash
# Build from command line
xcodebuild -project TimelyMeet.xcodeproj -scheme TimelyMeet build

# Run tests
xcodebuild test -project TimelyMeet.xcodeproj -scheme TimelyMeet -destination 'platform=macOS'

# Open in Xcode
open TimelyMeet.xcodeproj
```

## 🌟 Roadmap

### Upcoming Features

- 🎨 Theme customization


## 🤝 Contributing

We welcome contributions!

### Development Setup

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## 📄 License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE.md) file for details.

```
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```

## 📞 Support

- 🐛 Issues: [GitHub Issues](https://github.com/romancha/TimelyMeet/issues)


---

