//
//  CustomSoundService.swift
//  TimelyMeet
//
//  
//

import Foundation
import AVFoundation
import AppKit
import OSLog

@MainActor
class CustomSoundService: ObservableObject {
    @Published var availableSounds: [NotificationSound] = []
    @Published var selectedSound: NotificationSound = .default
    
    private var audioPlayer: AVAudioPlayer?
    private let appSettings = AppSettings.shared
    private let logger = Logger(subsystem: "org.romancha.timelymeet", category: "CustomSoundService")
    
    init() {
        setupAvailableSounds()
        loadSelectedSound()
    }
    
    private func setupAvailableSounds() {
        availableSounds = [
            NotificationSound.default,
            NotificationSound.system("Basso"),
            NotificationSound.system("Blow"),
            NotificationSound.system("Bottle"),
            NotificationSound.system("Frog"),
            NotificationSound.system("Funk"),
            NotificationSound.system("Glass"),
            NotificationSound.system("Hero"),
            NotificationSound.system("Morse"),
            NotificationSound.system("Ping"),
            NotificationSound.system("Pop"),
            NotificationSound.system("Purr"),
            NotificationSound.system("Sosumi"),
            NotificationSound.system("Submarine"),
            NotificationSound.system("Tink")
        ]
    }
    
    func playNotificationSound(_ sound: NotificationSound) {
        switch sound {
        case .default:
            NSSound.beep()
        case .system(let systemSound):
            NSSound(named: NSSound.Name(systemSound))?.play()
        }
    }
    
    private func playCustomSound(filename: String) {
        guard let url = Bundle.main.url(forResource: filename, withExtension: nil) else {
            logger.warning("Custom sound file not found: \(filename)")
            NSSound.beep() // Fallback
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            logger.error("Error playing custom sound: \(error.localizedDescription)")
            NSSound.beep()
        }
    }
    
    func previewSound(_ sound: NotificationSound) {
        playNotificationSound(sound)
    }
    
    func setSelectedSound(_ sound: NotificationSound) {
        selectedSound = sound
        appSettings.selectedNotificationSound = sound.identifier
    }
    
    func loadSelectedSound() {
        let identifier = appSettings.selectedNotificationSound
        selectedSound = availableSounds.first { $0.identifier == identifier } ?? .default
    }
}

// MARK: - NotificationSound Model

enum NotificationSound: CaseIterable, Identifiable {
    case `default`
    case system(String)
    
    var id: String { identifier }
    
    var identifier: String {
        switch self {
        case .default: return "default"
        case .system(let name): return "system_\(name)"
        }
    }
    
    var displayName: String {
        switch self {
        case .default: return "Default"
        case .system(let name): return name
        }
    }
    
    static var allCases: [NotificationSound] {
        return [
            .default,
            .system("Basso"),
            .system("Blow"), 
            .system("Bottle"),
            .system("Frog"),
            .system("Funk"),
            .system("Glass"),
            .system("Hero"),
            .system("Morse"),
            .system("Ping"),
            .system("Pop"),
            .system("Purr"),
            .system("Sosumi"),
            .system("Submarine"),
            .system("Tink")
        ]
    }
}

// MARK: - Visual Theme Support

enum NotificationTheme: String, CaseIterable, Identifiable {
    case system = "system"
    case classic = "classic"
    case light = "light"
    case dark = "dark"
    case vibrant = "vibrant"
    case minimal = "minimal"
    case professional = "professional"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .classic: return "Classic"
        case .light: return "Light"
        case .dark: return "Dark"
        case .vibrant: return "Vibrant"
        case .minimal: return "Minimal"
        case .professional: return "Professional"
        }
    }
    
    var description: String {
        switch self {
        case .system: return "Follows system appearance"
        case .classic: return "Original design before theme support"
        case .light: return "Light background with dark text"
        case .dark: return "Dark background with light text"
        case .vibrant: return "Colorful with enhanced contrast"
        case .minimal: return "Clean, distraction-free design"
        case .professional: return "Business-focused styling"
        }
    }
    
    // Visual properties for theming
    var backgroundColor: NSColor {
        switch self {
        case .system: return .controlBackgroundColor
        case .classic: return .black  // Original design used black background
        case .light: return .white
        case .dark: return .black
        case .vibrant: return NSColor.systemBlue.withAlphaComponent(0.1)
        case .minimal: return NSColor.controlBackgroundColor.withAlphaComponent(0.95)
        case .professional: return NSColor.systemGray.withAlphaComponent(0.05)
        }
    }
    
    var primaryTextColor: NSColor {
        switch self {
        case .system: return .labelColor
        case .classic: return .white  // Original design used white text
        case .light: return .black
        case .dark: return .white
        case .vibrant: return .systemBlue
        case .minimal: return .labelColor
        case .professional: return NSColor.controlTextColor
        }
    }
    
    var accentColor: NSColor {
        switch self {
        case .system: return .controlAccentColor
        case .classic: return .systemBlue  // Original design used system blue accents
        case .light: return .systemBlue
        case .dark: return .systemBlue
        case .vibrant: return .systemPurple
        case .minimal: return .systemGray
        case .professional: return NSColor.systemBlue.withAlphaComponent(0.8)
        }
    }
}

@MainActor
class NotificationThemeService: ObservableObject {
    @Published var selectedTheme: NotificationTheme = .system
    @Published var availableThemes: [NotificationTheme] = NotificationTheme.allCases
    
    private let appSettings = AppSettings.shared
    
    init() {
        loadSelectedTheme()
    }
    
    func setSelectedTheme(_ theme: NotificationTheme) {
        selectedTheme = theme
        appSettings.selectedNotificationTheme = theme.rawValue
    }
    
    private func loadSelectedTheme() {
        let themeString = appSettings.selectedNotificationTheme
        selectedTheme = NotificationTheme(rawValue: themeString) ?? .system
    }
}
