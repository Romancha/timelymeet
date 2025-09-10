//
//  LanguageSettingsView.swift
//  TimelyMeet
//
//  
//

import SwiftUI

struct LanguageSettingsView: View {
    @EnvironmentObject private var localizationManager: LocalizationManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("application_language".localized())
                .font(.title2)
                .fontWeight(.bold)
            
            GroupBox("application_language_title".localized()) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("language_description".localized())
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Picker("language_picker_label".localized(), selection: Binding(
                        get: { localizationManager.currentLocale.identifier },
                        set: { identifier in
                            let newLocale = Locale(identifier: identifier)
                            localizationManager.setLocale(newLocale)
                        }
                    )) {
                        ForEach(localizationManager.availableLocales, id: \.identifier) { locale in
                            let displayName = getDisplayName(for: locale)
                            Text(displayName)
                                .tag(locale.identifier)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 200, alignment: .leading)
                    
                    Divider()
                    
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        
                        Text("language_restart_required".localized())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            
            GroupBox("supported_languages_title".localized()) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(localizationManager.availableLocales, id: \.identifier) { locale in
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(.blue)
                            
                            Text(getDisplayName(for: locale))
                                .font(.body)
                            
                            Spacer()
                            
                            if locale.identifier == localizationManager.currentLocale.identifier {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    private func getDisplayName(for locale: Locale) -> String {
        switch locale.identifier {
        case "en":
            return "English"
        case "ru":
            return "Русский (Russian)"
        default:
            if #available(macOS 13.0, *) {
                return locale.localizedString(forIdentifier: locale.identifier) ?? "English"
            } else {
                return locale.localizedString(forLanguageCode: locale.languageCode ?? "en") ?? "English"
            }
        }
    }
}

#Preview {
    LanguageSettingsView()
        .environmentObject(LocalizationManager.shared)
}
