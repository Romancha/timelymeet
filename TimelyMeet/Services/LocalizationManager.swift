//
//  LocalizationManager.swift
//  TimelyMeet
//
//  
//

import Foundation
import SwiftUI

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @Published var currentLocale: Locale
    
    private let localeKey = "selectedLocale"
    
    private init() {
        // Initialize with saved locale or default
        if let savedLocaleIdentifier = UserDefaults.standard.string(forKey: "selectedLocale") {
            self.currentLocale = Locale(identifier: savedLocaleIdentifier)
        } else {
            self.currentLocale = Locale.current
        }
    }
    
    @MainActor
    func setLocale(_ locale: Locale) {
        currentLocale = locale
        // Save the selected locale to UserDefaults
        UserDefaults.standard.set(locale.identifier, forKey: localeKey)
    }
    
    func localizedString(for key: String, defaultValue: String? = nil) -> String {
        // Get the current locale identifier
        let localeIdentifier = currentLocale.identifier
        
        // Get the bundle path for the specific locale
        guard let bundlePath = Bundle.main.path(forResource: localeIdentifier, ofType: "lproj"),
              let bundle = Bundle(path: bundlePath) else {
            // If specific locale bundle is not found, try language code only
            let languageCode = currentLocale.language.languageCode?.identifier ?? "en"
            guard let fallbackBundlePath = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
                  let fallbackBundle = Bundle(path: fallbackBundlePath) else {
                // If no bundle found, return default value or key
                return defaultValue ?? key
            }
            
            let localizedString = NSLocalizedString(key, bundle: fallbackBundle, comment: "")
            return localizedString == key ? (defaultValue ?? key) : localizedString
        }
        
        // Get localized string from the specific bundle
        let localizedString = NSLocalizedString(key, bundle: bundle, comment: "")
        
        // If localization is not found, return the default value or key
        if localizedString == key {
            return defaultValue ?? key
        }
        
        return localizedString
    }
    
    @MainActor
    var availableLocales: [Locale] {
        return [
            Locale(identifier: "en"),
            Locale(identifier: "ru")
        ]
    }
    
    @MainActor
    var currentLanguageDisplayName: String {
        if #available(macOS 13, *) {
            return currentLocale.localizedString(forLanguageCode: currentLocale.language.languageCode?.identifier ?? "en") ?? "English"
        } else {
            return currentLocale.localizedString(forLanguageCode: currentLocale.languageCode ?? "en") ?? "English"
        }
    }
}

// Environment key for localization
struct LocalizationEnvironmentKey: EnvironmentKey {
    nonisolated static let defaultValue: LocalizationManager = {
        if Thread.isMainThread {
            return LocalizationManager.shared
        } else {
            return DispatchQueue.main.sync {
                LocalizationManager.shared
            }
        }
    }()
}

extension EnvironmentValues {
    var localizationManager: LocalizationManager {
        get { self[LocalizationEnvironmentKey.self] }
        set { self[LocalizationEnvironmentKey.self] = newValue }
    }
}

// String extension for easier localization
extension String {
    func localized(defaultValue: String? = nil) -> String {
        return LocalizationManager.shared.localizedString(for: self, defaultValue: defaultValue)
    }
}

// SwiftUI View extension for easier localization
extension View {
    func localized() -> some View {
        self.environment(\.locale, LocalizationManager.shared.currentLocale)
            .environmentObject(LocalizationManager.shared)
    }
}
