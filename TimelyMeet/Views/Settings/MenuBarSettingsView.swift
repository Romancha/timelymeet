//
//  MenuBarSettingsView.swift
//  TimelyMeet
//
//  
//

import SwiftUI

struct MenuBarSettingsView: View {
    @EnvironmentObject private var menuBarService: MenuBarService
    @EnvironmentObject private var appModel: AppModel
    @ObservedObject private var appSettings = AppSettings.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("menu_bar_display".localized())
                .font(.title2)
                .fontWeight(.bold)
            
            Text("menu_bar_customize".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 20) {
                // Time Threshold Settings
                GroupBox("display_timing".localized()) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("show_meeting_info_when".localized())
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("next_meeting_within".localized())
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(String(format: "hours_format".localized(), appSettings.menuBarDisplayThreshold))
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            }
                            
                            Slider(value: $appSettings.menuBarDisplayThreshold, in: 0.5...48.0, step: 0.5) {
                                Text("time_threshold".localized())
                            }
                            .onChange(of: appSettings.menuBarDisplayThreshold) { _, newValue in
                                menuBarService.updateDisplayThreshold(hours: newValue)
                            }
                            
                            HStack {
                                Text("hours_30min".localized())
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("hours_48".localized())
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Divider()
                        
                        Text("examples_title".localized())
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 6, height: 6)
                                Text("example_1_hour".localized())
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Circle()
                                    .fill(Color.accentColor)
                                    .frame(width: 6, height: 6)
                                Text("example_8_hours".localized())
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 6, height: 6)
                                Text("example_24_hours".localized())
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Display Options
                GroupBox("display_options_title".localized()) {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("show_meeting_time_countdown".localized(), isOn: $appSettings.menuBarShowTime)
                            .onChange(of: appSettings.menuBarShowTime) { _, newValue in
                                menuBarService.updateDisplayOptions(showTime: newValue, showEventTitle: appSettings.menuBarShowEventTitle)
                            }
                        
                        Toggle("show_event_title".localized(), isOn: $appSettings.menuBarShowEventTitle)
                            .onChange(of: appSettings.menuBarShowEventTitle) { _, newValue in
                                menuBarService.updateDisplayOptions(showTime: appSettings.menuBarShowTime, showEventTitle: newValue)
                            }
                        
                        if appSettings.menuBarShowEventTitle {
                            Text("truncated_characters_note".localized())
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading)
                        }
                        
                        Toggle("auto_width_mode".localized(), isOn: $appSettings.statusBarAutoWidth)
                        
                        if appSettings.statusBarAutoWidth {
                            Text("auto_width_description".localized())
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("manual_width_setting".localized())
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(String(format: "width_points_format".localized(), Int(appSettings.statusBarWidthPt)))
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                }
                                
                                Slider(value: $appSettings.statusBarWidthPt, in: appSettings.menuBarMinBudget...appSettings.menuBarMaxBudget, step: 5) {
                                    Text("width_slider".localized())
                                }
                                
                                HStack {
                                    Text(String(format: "width_points_format".localized(),  Int(appSettings.menuBarMinBudget)))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(String(format: "width_points_format".localized(), Int(appSettings.menuBarMaxBudget)))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
        
                
                // Preview Section
                GroupBox("preview_title".localized()) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("current_menu_bar_preview_title".localized())
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        MenuBarLabelView()
                            .environmentObject(appModel.menuBarService)
                            .environmentObject(appModel)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                    }
                }
            }
        }
    }
}
