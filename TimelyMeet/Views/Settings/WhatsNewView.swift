//
//  WhatsNewView.swift
//  TimelyMeet
//
//  
//

import SwiftUI

struct WhatsNewView: View {
    @StateObject private var releaseNotesService = ReleaseNotesService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            
            Text("whats_new_title".localized())
                .font(.title2)
                .fontWeight(.bold)
            
            // Release Notes Section
            if !releaseNotesService.releaseNotes.isEmpty {
                GroupBox("release_notes_title".localized()) {
                    
                    VStack(alignment: .leading, spacing: 12) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                ForEach(releaseNotesService.releaseNotes, id: \.id) { release in
                                    ReleaseNoteRow(release: release)
                                }
                            }
                        }
                        .frame(maxHeight: 300)
                    }
                }

            }
            
            // Future Updates Section
            GroupBox("coming_soon".localized()) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "clock.circle")
                            .foregroundColor(.blue)
                        
                        Text("future_updates_title".localized())
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    Text("app_improvement_message".localized())
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        UpcomingFeatureRow(icon: "paintbrush.fill", title: "theme_support".localized(), description: "theme_support_description".localized())
                        CompletedFeatureRow(icon: "terminal.fill", title: "open_source_release".localized(), description: "open_source_release_description".localized())
                    }
                }
            }
            
            // Feedback Section
            GroupBox("feedback_matters".localized()) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "heart.circle.fill")
                            .foregroundColor(.red)
                        
                        Text("help_improve_title".localized())
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    Text("app_feedback_message".localized())
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        Button("send_feedback".localized()) {
                            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
                            
                            let subject = "TimeMeet Feedback \(version) (\(build))"
                            let body = "\n\n\(SystemInfo.systemInfoString())"
                            
                            let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                            let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                            
                            if let url = URL(string: "mailto:romanchabest55@gmail.com?subject=\(encodedSubject)&body=\(encodedBody)") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("rate_app_store".localized()) {
                            if let url = URL(string: "https://apps.apple.com/ru/app/timelymeet/id6751949087") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.bordered)
                        
                        Button {
                            NSWorkspace.shared.open(URL(string: "https://github.com/Romancha/timelymeet")!)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "terminal.fill")
                                Text("source_code".localized())
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }
}


struct UpcomingFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "clock.circle")
                .foregroundColor(.orange)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

struct CompletedFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

struct ReleaseNoteRow: View {
    let release: ReleaseNote
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack() {
                Image(systemName: "tag.fill")
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("version_label".localized() + " \(release.version)")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    if let releaseDate = release.formattedDate {
                        Text(DateFormatter.releaseDate.string(from: releaseDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                let featureChanges = release.changes.filter { $0.type == .feature }
                let improvementChanges = release.changes.filter { $0.type == .improvement }
                let bugfixChanges = release.changes.filter { $0.type == .bugfix }
                
                if !featureChanges.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: ChangeType.feature.icon)
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text(ChangeType.feature.displayName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(featureChanges) { change in
                                Text("• " + change.description.localized())
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(.leading, 24)
                    }
                }
                
                if !improvementChanges.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: ChangeType.improvement.icon)
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text(ChangeType.improvement.displayName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(improvementChanges) { change in
                                Text("• " + change.description.localized())
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(.leading, 24)
                    }
                }
                
                if !bugfixChanges.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: ChangeType.bugfix.icon)
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text(ChangeType.bugfix.displayName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(bugfixChanges) { change in
                                Text("• " + change.description.localized())
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(.leading, 24)
                    }
                }
            }
            .padding(.leading, 24)
        }
        .padding(.vertical, 4)
    }
}

extension DateFormatter {
    static let releaseDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

#Preview {
    ScrollView {
        WhatsNewView()
    }
    .frame(width: 600, height: 800)
    .padding()
}
