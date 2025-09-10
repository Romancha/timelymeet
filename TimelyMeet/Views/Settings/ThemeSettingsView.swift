//
//  ThemeSettingsView.swift
//  TimelyMeet
//
//  
//

import SwiftUI

struct ThemeSettingsView: View {
    @EnvironmentObject private var themeService: NotificationThemeService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Visual Themes")
                .font(.title2)
                .fontWeight(.bold)
            
            GroupBox("Theme Selection") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 16) {
                    ForEach(themeService.availableThemes) { theme in
                        ThemePreviewCard(
                            theme: theme,
                            isSelected: themeService.selectedTheme == theme
                        ) {
                            themeService.setSelectedTheme(theme)
                        }
                    }
                }
            }
        }
    }
}

struct ThemePreviewCard: View {
    let theme: NotificationTheme
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Fullscreen notification preview
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(theme.backgroundColor).opacity(0.85))
                .overlay(
                    VStack(spacing: 12) {
                        // Top bar simulation
                        HStack {
                            Text("14:30")
                                .font(.caption2)
                                .foregroundColor(theme == .classic ? Color.white.opacity(0.9) : Color(theme.primaryTextColor).opacity(0.8))
                                .fontDesign(.monospaced)
                            Spacer()
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(theme == .classic ? Color.white.opacity(0.7) : Color(theme.primaryTextColor).opacity(0.6))
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 4)
                        
                        // Urgency indicator
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 4, height: 4)
                            Text("MEETING STARTING SOON")
                                .font(.system(size: 6, weight: .bold, design: .rounded))
                                .foregroundColor(.orange)
                                .tracking(1)
                        }
                        
                        // Meeting title
                        Text("Daily Standup")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(theme == .classic ? Color.white : Color(theme.primaryTextColor))
                            .multilineTextAlignment(.center)
                        
                        // Time remaining
                        Text("2:34")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(.orange)
                        
                        // Action buttons preview
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray, lineWidth: 1)
                                .frame(width: 30, height: 12)
                                .overlay(
                                    Text("Dismiss")
                                        .font(.system(size: 4))
                                        .foregroundColor(.gray)
                                )
                            
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.orange, lineWidth: 1)
                                .frame(width: 30, height: 12)
                                .overlay(
                                    Text("Snooze")
                                        .font(.system(size: 4))
                                        .foregroundColor(.orange)
                                )
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blue)
                                .frame(width: 30, height: 12)
                                .overlay(
                                    Text("Join")
                                        .font(.system(size: 4))
                                        .foregroundColor(.white)
                                )
                        }
                        .padding(.bottom, 4)
                    }
                        .padding(6)
                )
                .frame(height: 140)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                )
            
            Text(theme.displayName)
                .font(.headline)
            
            Text(theme.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
            
            if isSelected {
                Button("Selected") {
                    onSelect()
                }
                .buttonStyle(BorderedProminentButtonStyle())
                .controlSize(.small)
                .disabled(true)
            } else {
                Button("Select") {
                    onSelect()
                }
                .buttonStyle(BorderedButtonStyle())
                .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}