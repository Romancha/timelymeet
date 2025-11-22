# TimelyMeet

<div align="center">

<!-- App Icon -->
<img src="TimelyMeet/Assets.xcassets/AppIcon.appiconset/AppIcon-128.png" alt="TimelyMeet Icon" width="128" height="128">

### Stay timely. Never miss a meet.
#### Meeting Notifications for macOS

<!-- App Store Badge -->
[![Download on the App Store](https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg)](https://apps.apple.com/app/timelymeet/id6751949087)

![GitHub release (with filter)](https://img.shields.io/github/v/release/romancha/TimelyMeet)
![GitHub Release Date - Published_At](https://img.shields.io/github/release-date/romancha/TimelyMeet)
![macOS](https://img.shields.io/badge/macOS-15.0+-blue?logo=apple)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Framework-blue)
![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)
[![GitHub stars](https://img.shields.io/github/stars/romancha/TimelyMeet?style=social)](https://github.com/romancha/TimelyMeet/stargazers)

[Features](#-features) • [Installation](#-getting-started) • [Contributing](#-contributing)

---

</div>

## 🎯 Why TimelyMeet?

**Ever been late to an important meeting because you didn't notice the notification?**

TimelyMeet was born from personal frustration with missing Zoom calls and being "that person" who joins 5 minutes late. It sits in your macOS menu bar and fire full screen alert with one-click meeting join, so you never miss another important call.

<div align="center">
<img src="docs/screenshot-main.png" alt="TimelyMeet Main Interface" width="800">
</div>

## ✨ Features

### Core Functionality

🚨 **Fullscreen Alerts**
Beautiful, attention-grabbing fullscreen notifications ensure you never miss an important meeting.

⚡ **One-Click Join**
Instantly join Zoom, Google Meet, Microsoft Teams, and other video conferences with smart URL detection.

📊 **Menu Bar Integration**
Your upcoming meetings are always visible in the menu bar with countdown timers and quick access.

### Customization

🔔 **Smart Notifications**
Configure custom reminder times, notification sounds, and alert preferences for different meeting types.

⌨️ **Keyboard Shortcuts**
- `ESC` to dismiss
- `Enter` to join meeting
- `S` to snooze (3 minutes)
- Hold snooze button for custom time options

### Privacy & Cost

💎 **Completely Free**
No subscriptions, no hidden fees, no premium tiers - all features are free forever.

🔒 **Privacy First**
Your calendar data never leaves your device. No tracking, no analytics, no data collection. Period.

## 🌐 Website

**🔗 [timelymeet.romancha.org](https://timelymeet.romancha.org)**

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

## 📞 Support & Community

### Need Help?

- 🐛 **Bug Reports**: [GitHub Issues](https://github.com/romancha/TimelyMeet/issues)
- 💡 **Feature Requests**: [GitHub Discussions](https://github.com/romancha/TimelyMeet/discussions)
- 🌐 **Website**: [timelymeet.romancha.org](https://timelymeet.romancha.org)

### Love TimelyMeet?

If TimelyMeet helps you stay on time, consider:

- ⭐ **Star this repository** to help others discover it
- 🐦 **Share on Twitter/X** with `#TimelyMeet`
- 📝 **Write a review** on the App Store
- 🤝 **Contribute** code, documentation, or translations

---

<div align="center">

**Made by [Roman Makarskiy](https://romancha.org)**

Built with SwiftUI • Open Source • Privacy First

[Website](https://timelymeet.romancha.org) • [App Store](https://apps.apple.com/app/timelymeet/id6751949087) • [GitHub](https://github.com/romancha/TimelyMeet)

</div>

