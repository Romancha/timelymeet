//
//  CalendarPermissionNotification.swift
//  TimelyMeet
//
//  
//

import SwiftUI
import AppKit

struct CalendarPermissionNotification: View {
    @EnvironmentObject private var calendarViewModel: CalendarViewModel
    
    let showDivider: Bool
    
    init(showDivider: Bool = true) {
        self.showDivider = showDivider
    }
    
    var body: some View {
        if needsPermissionNotification {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("calendar_access_required".localized())
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Text("calendar_permission_message".localized())
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                Button(action: {
                    openSystemPreferences()
                }) {
                    HStack {
                        Image(systemName: "gear")
                        Text("open_system_settings".localized())
                    }
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
            
            if showDivider {
                Divider()
                    .padding(.vertical, 8)
            }
        }
    }
    
    private var needsPermissionNotification: Bool {
        calendarViewModel.authorizationStatus != .fullAccess
    }
    
    private func openSystemPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!
        NSWorkspace.shared.open(url)
    }
}

#Preview {
    CalendarPermissionNotification()
        .environmentObject(CalendarViewModel.withDemoData())
}