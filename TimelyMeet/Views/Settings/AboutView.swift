//
//  AboutView.swift
//  TimelyMeet
//
//
//

import SwiftUI

struct AboutView: View {
    @EnvironmentObject private var developerModeService: DeveloperModeService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Button("about_meetalert".localized()) {
                    developerModeService.handleAboutTabClick()
                }
                .font(.title2)
                .fontWeight(.bold)
                .buttonStyle(.plain)
                .foregroundColor(.primary)
                
                Spacer()
                
                // Show subtle progress for developer mode activation
                if developerModeService.aboutClickCount > 4 && developerModeService.aboutClickCount < 10 {
                    Text("\(developerModeService.aboutClickCount)/10")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .opacity(0.6)
                }
            }
            
            // App Icon and Info Section
            GroupBox {
                VStack(spacing: 20) {
                    // App Icon and basic info
                    HStack(spacing: 20) {
                        // App Icon
                        Image("AppIconImage")
                            .resizable()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.1), radius: 4)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("app_name".localized())
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text(String(format: "version_format".localized(), Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0", Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("app_description".localized())
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    Divider()
                    
                    // Description
                    VStack(alignment: .leading, spacing: 12) {
                        Text("about_meetalert".localized())
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("app_info_description".localized())
                            .font(.body)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        
                        Text("features_title".localized())
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.top, 8)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            FeatureRowWithDescription(icon: "bell.fill", title: "feature_fullscreen_alerts".localized(), description: "feature_fullscreen_alerts_description".localized())
                            FeatureRowWithDescription(icon: "video.circle.fill", title: "feature_fast_join".localized(), description: "feature_fast_join_description".localized())
                            FeatureRowWithDescription(icon: "bell.circle.fill", title: "feature_notifications".localized(), description: "feature_notifications_description".localized())
                            FeatureRowWithDescription(icon: "menubar.rectangle", title: "feature_menubar".localized(), description: "feature_menubar_description".localized())
                            FeatureRowWithDescription(icon: "keyboard.fill", title: "feature_shortcuts".localized(), description: "feature_shortcuts_description".localized())
                            FeatureRowWithDescription(icon: "heart.fill", title: "feature_free_solution".localized(), description: "feature_free_solution_description".localized())
                            FeatureRowWithDescription(icon: "lock.shield.fill", title: "feature_data_protection".localized(), description: "feature_data_protection_description".localized())
                        }
                    }
                }
            }
            
            // Copyright and Legal Section
            GroupBox("legal".localized()) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("copyright".localized())
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Text("app_integration_description".localized())
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 16) {
                        Button("privacy_policy".localized()) {
                            NSWorkspace.shared.open(URL(string: "https://romancha.org/timelymeet/privacy-policy.html")!)
                        }
                        .buttonStyle(.link)
                        
                        Button("report_issue".localized()) {
                            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
                            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
                            
                            let subject = "TimeMeet \(version) (\(build))"
                            let body = "\n\n\(SystemInfo.systemInfoString())"
                            
                            let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                            let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                            
                            if let url = URL(string: "mailto:romanchabest55@gmail.com?subject=\(encodedSubject)&body=\(encodedBody)") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.link)
                        
                        Spacer()
                    }
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 16)
            
            Text(text)
                .font(.body)
                .foregroundColor(.primary)
        }
    }
}

struct FeatureRowWithDescription: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.system(size: 16))
                .frame(width: 20)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
                .textSelection(.enabled)
        }
    }
}


// Extension to get build date
extension Bundle {
    var buildDate: Date? {
        guard let infoPath = path(forResource: "Info", ofType: "plist"),
              let infoAttr = try? FileManager.default.attributesOfItem(atPath: infoPath),
              let date = infoAttr[.creationDate] as? Date else { return nil }
        return date
    }
}



#Preview {
    ScrollView {
        AboutView()
            .environmentObject(DeveloperModeService.shared)
    }
    .frame(width: 600, height: 800)
    .padding()
}
