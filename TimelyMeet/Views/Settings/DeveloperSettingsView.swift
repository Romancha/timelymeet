//
//  DeveloperSettingsView.swift
//  TimelyMeet
//
//  
//

import SwiftUI

struct DeveloperSettingsView: View {
    @EnvironmentObject private var developerModeService: DeveloperModeService
    @EnvironmentObject private var videoConferenceManager: VideoConferenceManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("developer_tools".localized())
                .font(.title2)
                .fontWeight(.bold)
            
            if developerModeService.isDevModeEnabled {
                DeveloperModeView()
                    .environmentObject(developerModeService)
                    .environmentObject(videoConferenceManager)
            } else {
                GroupBox {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.largeTitle)
                        
                        Text("developer_mode_required".localized())
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text("enable_developer_mode_description".localized())
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}
