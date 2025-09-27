//
//  CalendarSettingsView.swift
//  TimelyMeet
//
//  
//

import SwiftUI

struct CalendarSettingsView: View {
    @EnvironmentObject private var calendarViewModel: CalendarViewModel
    @EnvironmentObject private var backgroundSync: BackgroundSyncService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("calendar_integration_title".localized())
                .font(.title2)
                .fontWeight(.bold)
            
            // Calendar permission notification (if needed)
            CalendarPermissionNotification(showDivider: false)
            
            GroupBox("sync_status_title".localized()) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        StatusIndicator(status: backgroundSync.syncStatus)
                        
                        VStack(alignment: .leading) {
                            Text(String(format: "background_sync_status".localized(), backgroundSync.syncStatus.displayText))
                                .fontWeight(.medium)
                            
                            if let lastSync = backgroundSync.lastSyncTime {
                                Text("Last sync: \(lastSync.formatted(.relative(presentation: .named)))".localized())
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button("sync_now".localized()) {
                            Task {
                                await backgroundSync.performManualSync()
                            }
                        }
                        .buttonStyle(.liquidGlass(isProminent: true, size: .regular))
                        .disabled(backgroundSync.syncStatus == .syncing)
                    }
                }
            }
            
            GroupBox("calendar_selection_title".localized()) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("calendar_selection_description_text".localized())
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(calendarViewModel.calendars, id: \.calendarIdentifier) { calendar in
                        HStack {
                            Toggle("", isOn: Binding(
                                get: { calendarViewModel.isCalendarSelected(calendar) },
                                set: { _ in calendarViewModel.toggleCalendar(calendar) }
                            ))
                            .toggleStyle(.checkbox)
                            
                            Circle()
                                .fill(Color(calendar.cgColor))
                                .frame(width: 12, height: 12)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(calendar.title)
                                    .fontWeight(.medium)
                                
                                if let source = calendar.source?.title {
                                    Text(source)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if calendarViewModel.isCalendarSelected(calendar) {
                                Text("\(calendarViewModel.events.filter { $0.calendar == calendar }.count) meetings".localized())
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(.regularMaterial)
                                            .overlay(
                                                Capsule()
                                                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 0.5)
                                            )
                                    )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    if calendarViewModel.calendars.isEmpty {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("no_calendars_available_message".localized())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    Divider()
                    
                    HStack {
                        Button("select_all_button".localized()) {
                            calendarViewModel.selectAllCalendars()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button("deselect_all_button".localized()) {
                            calendarViewModel.deselectAllCalendars()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Spacer()
                        
                        Text("\(calendarViewModel.selectedCalendars.count) of \(calendarViewModel.calendars.count) selected".localized())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

struct StatusIndicator: View {
    let status: SyncStatus
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 12, height: 12)
    }
    
    private var color: Color {
        switch status {
        case .idle: return .gray
        case .syncing: return .blue
        case .success: return .green
        case .paused: return .orange
        case .error: return .red
        }
    }
}

extension SyncStatus {
    var displayText: String {
        switch self {
        case .idle: return "idle_status".localized()
        case .syncing: return "syncing_status".localized()
        case .success: return "up_to_date_status".localized()
        case .paused: return "paused_status".localized()
        case .error(let error): return "Error - \(error.localizedDescription)".localized()
        }
    }
}
