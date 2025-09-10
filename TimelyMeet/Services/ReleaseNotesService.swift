import Foundation
import OSLog

@MainActor
class ReleaseNotesService: ObservableObject {
    @Published var releaseNotes: [ReleaseNote] = []
    @Published var isLoading = false
    
    private let logger = Logger(subsystem: "org.romancha.timelymeet", category: "ReleaseNotesService")
    
    static let shared = ReleaseNotesService()
    
    private init() {
        loadReleaseNotes()
    }
    
    func loadReleaseNotes() {
        isLoading = true
        
        guard let url = Bundle.main.url(forResource: "release_notes", withExtension: "json") else {
            logger.error("Could not find release_notes.json in bundle")
            isLoading = false
            return
        }
        
        do {
            let jsonData = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let releaseNotesData = try decoder.decode(ReleaseNotesData.self, from: jsonData)
            
            // Sort by version descending (newest first)
            self.releaseNotes = releaseNotesData.releaseNotes.sorted { note1, note2 in
                // Simple version comparison - assumes semantic versioning
                return note1.version.compare(note2.version, options: .numeric) == .orderedDescending
            }
            
            logger.info("Successfully loaded \(self.releaseNotes.count) release notes")
            
        } catch {
            logger.error("Failed to load release notes: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func getLatestVersion() -> String? {
        return releaseNotes.first?.version
    }
    
    func getReleaseNote(for version: String) -> ReleaseNote? {
        return releaseNotes.first { $0.version == version }
    }
}