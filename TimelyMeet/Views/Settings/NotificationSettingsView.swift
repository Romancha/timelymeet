//
//  NotificationSettingsView.swift
//  TimelyMeet
//
//  
//

import SwiftUI

struct NotificationSettingsView: View {
    @EnvironmentObject private var notificationScheduler: NotificationScheduler
    @EnvironmentObject private var customSoundService: CustomSoundService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("notifications_title".localized())
                .font(.title2)
                .fontWeight(.bold)
            
            ReminderTimesSelector()
            
            Divider()
            
            SoundSelectionSection()
                .environmentObject(customSoundService)
        }
    }
}

struct ReminderTimesSelector: View {
    @ObservedObject private var appSettings = AppSettings.shared
    @EnvironmentObject private var notificationScheduler: NotificationScheduler
    
    private var reminderTimes: [Int] {
        get {
            return appSettings.reminderTimes
        }
        nonmutating set {
            appSettings.setReminderTimes(newValue)
            
            // Refresh notifications with new settings
            DispatchQueue.main.async {
                notificationScheduler.refreshNotificationsAfterSettingsChange()
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("reminder_times_title".localized())
                .font(.headline)
            
            HStack {
                ForEach(AppSettings.NotificationDefaults.availableReminderTimes, id: \.self) { seconds in
                    Toggle(formatTimeLabel(seconds), isOn: Binding(
                        get: { reminderTimes.contains(seconds) },
                        set: { isOn in
                            if isOn {
                                reminderTimes.append(seconds)
                            } else {
                                reminderTimes.removeAll { $0 == seconds }
                            }
                        }
                    ))
                    .toggleStyle(.button)
                    .controlSize(.small)
                }
            }
            
            Text("select_reminder_times_description".localized())
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func formatTimeLabel(_ seconds: Int) -> String {
        if seconds == 0 {
            return "meeting_time_label".localized()
        } else if seconds < 60 {
            return "\(seconds)s"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m"
        } else {
            let hours = seconds / 3600
            let minutes = (seconds % 3600) / 60
            return "\(hours)h \(minutes)m"
        }
    }
}

struct SoundSelectionSection: View {
    @EnvironmentObject private var customSoundService: CustomSoundService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("notification_sound_title".localized())
                .font(.headline)
            
            VStack(spacing: 8) {
                ForEach(customSoundService.availableSounds) { sound in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sound.displayName)
                                .font(.body)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Button("preview_button".localized()) {
                                customSoundService.previewSound(sound)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            if customSoundService.selectedSound.id == sound.id {
                                Button("selected_button".localized()) {}
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                    .disabled(true)
                            } else {
                                Button("select_button".localized()) {
                                    customSoundService.setSelectedSound(sound)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    
                    if sound.id != customSoundService.availableSounds.last?.id {
                        Divider()
                    }
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
}
