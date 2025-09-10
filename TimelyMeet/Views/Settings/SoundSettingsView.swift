//
//  SoundSettingsView.swift
//  TimelyMeet
//
//  
//

import SwiftUI

struct SoundSettingsView: View {
    @EnvironmentObject private var customSoundService: CustomSoundService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Notification Sounds")
                .font(.title2)
                .fontWeight(.bold)
            
            SoundSelectionList()
                .environmentObject(customSoundService)
        }
    }
}

struct SoundSelectionList: View {
    @EnvironmentObject private var customSoundService: CustomSoundService
    
    var body: some View {
        GroupBox("Sound Selection") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(customSoundService.availableSounds) { sound in
                    SoundSelectionRow(sound: sound)
                        .environmentObject(customSoundService)
                }
            }
        }
    }
}

struct SoundSelectionRow: View {
    let sound: NotificationSound
    @EnvironmentObject private var customSoundService: CustomSoundService
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(sound.displayName)
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            Button("Preview") {
                customSoundService.previewSound(sound)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            if customSoundService.selectedSound.id == sound.id {
                Button("Selected") {
                    customSoundService.setSelectedSound(sound)
                }
                .buttonStyle(BorderedProminentButtonStyle())
                .controlSize(.small)
                .disabled(true)
            } else {
                Button("Select") {
                    customSoundService.setSelectedSound(sound)
                }
                .buttonStyle(BorderedButtonStyle())
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}
