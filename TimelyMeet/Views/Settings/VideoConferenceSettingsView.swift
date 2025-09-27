//
//  VideoConferenceSettingsView.swift
//  TimelyMeet
//

import SwiftUI

struct VideoConferenceSettingsView: View {
    @StateObject private var preferences = VideoConferencePreferences()
    @StateObject private var appSettings = AppSettings.shared
    @State private var searchText = ""
    
    private var filteredPlatforms: [VideoConferencePlatform] {
        let platforms = VideoConferencePlatform.allCases.filter { $0 != .unknown }
        
        if searchText.isEmpty {
            return platforms
        } else {
            return platforms.filter { platform in
                platform.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("video_conference_settings_title".localized())
                .font(.title2)
                .fontWeight(.semibold)
            
            // Provider-specific settings
            GroupBox("browser_provider_specific_settings".localized()) {
                VStack(spacing: 12) {
                    // Search field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("browser_search_providers_placeholder".localized(), text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onSubmit {
                                // Keep focus in search field after search
                            }
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.horizontal, 4)
                    
                    // Results info
                    if !searchText.isEmpty {
                        HStack {
                            Text("Found \(filteredPlatforms.count) provider\(filteredPlatforms.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                    }
                    
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if filteredPlatforms.isEmpty {
                                Text("browser_no_providers_found".localized())
                                    .foregroundColor(.secondary)
                                    .padding()
                            } else {
                                ForEach(filteredPlatforms, id: \.self) { platform in
                            ProviderSettingsRow(
                                platform: platform,
                                strategy: Binding(
                                    get: { preferences.strategyFor(provider: platform) },
                                    set: { preferences.setStrategy($0, for: platform) }
                                ),
                                browser: Binding(
                                    get: { preferences.browserFor(provider: platform) },
                                    set: { preferences.setBrowser($0, for: platform) }
                                ),
                                hasCustomSettings: {
                                    let currentStrategy = preferences.strategyFor(provider: platform)
                                    let currentBrowser = preferences.browserFor(provider: platform)
                                    let recommendedStrategy = preferences.recommendedStrategyFor(provider: platform)
                                    let recommendedBrowser = preferences.recommendedBrowserFor(provider: platform)
                                    return currentStrategy != recommendedStrategy || currentBrowser != recommendedBrowser
                                }(),
                                onResetToDefault: {
                                    preferences.resetToRecommended(for: platform)
                                }
                                )
                                }
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 4)
                    }
                    .frame(maxHeight: 550)
                }
            }
            
            Spacer()
        }
        .padding(20)
        .frame(minWidth: 600, maxWidth: 800, minHeight: 650, maxHeight: 900)
    }
}

struct ProviderSettingsRow: View {
    let platform: VideoConferencePlatform
    @Binding var strategy: OpeningStrategy
    @Binding var browser: BrowserChoice
    let hasCustomSettings: Bool
    let onResetToDefault: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Header with platform name and reset button
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: platform.iconName)
                        .frame(width: 16)
                        .foregroundColor(.primary)
                    Text(platform.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                if hasCustomSettings {
                    Button("browser_reset_to_default".localized()) {
                        onResetToDefault()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .foregroundColor(.orange)
                }
            }
            
            // Settings grid
            HStack(spacing: 20) {
                // Strategy section
                VStack(alignment: .leading, spacing: 4) {
                    Text("browser_opening_method_title".localized())
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("browser_strategy_title".localized(), selection: $strategy) {
                        ForEach(OpeningStrategy.allCases, id: \.self) { strat in
                            Text(strat.displayName).tag(strat)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Browser section
                VStack(alignment: .leading, spacing: 4) {
                    Text("browser_section_title".localized())
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("browser_section_title".localized(), selection: $browser) {
                        ForEach(BrowserChoice.allCases, id: \.self) { browserChoice in
                            Text(browserChoice.displayName).tag(browserChoice)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            Group {
                if hasCustomSettings {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }
            }
        )
    }
}


#Preview {
    VideoConferenceSettingsView()
}
