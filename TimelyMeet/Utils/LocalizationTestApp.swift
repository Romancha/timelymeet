//
//  LocalizationTestApp.swift
//  TimelyMeet
//
//  
//

import SwiftUI

struct LocalizationTestApp: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Settings")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Language")
                .font(.headline)
            
            Text("developer_tools")
                .font(.body)
            
            Text("Analytics")
                .font(.body)
            
            LanguageSettingsView()
                .environmentObject(LocalizationManager.shared)
                .frame(width: 400, height: 300)
        }
        .padding()
        .frame(width: 500, height: 600)
    }
}

#Preview {
    LocalizationTestApp()
        .environmentObject(LocalizationManager.shared)
}
