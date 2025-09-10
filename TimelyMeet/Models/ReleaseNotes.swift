import Foundation

struct ReleaseNotesData: Codable {
    let releaseNotes: [ReleaseNote]
}

struct ReleaseNote: Codable, Identifiable {
    let version: String
    let date: String
    let changes: [ChangeItem]
    
    var id: String { version }
    
    var formattedDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date)
    }
}

struct ChangeItem: Codable, Identifiable {
    let type: ChangeType
    let description: LocalizedDescription
    
    var id: String { "\(type.rawValue)_\(description.en.prefix(50))" }
}

struct LocalizedDescription: Codable {
    let en: String
    let ru: String
    
    func localized() -> String {
        let currentLanguage = Locale.current.language.languageCode?.identifier ?? "en"
        return currentLanguage == "ru" ? ru : en
    }
}

enum ChangeType: String, Codable, CaseIterable {
    case feature = "feature"
    case bugfix = "bugfix"
    case improvement = "improvement"
    
    var displayName: String {
        switch self {
        case .feature:
            return "release_notes_feature".localized()
        case .bugfix:
            return "release_notes_bugfix".localized()
        case .improvement:
            return "release_notes_improvement".localized()
        }
    }
    
    var icon: String {
        switch self {
        case .feature:
            return "sparkles"
        case .bugfix:
            return "ladybug.slash"
        case .improvement:
            return "chevron.up.2"
        }
    }
}
