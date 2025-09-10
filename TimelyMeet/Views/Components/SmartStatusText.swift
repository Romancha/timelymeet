//
//  SmartStatusText.swift
//  TimelyMeet
//
//  Created on 02.09.2025.
//

import SwiftUI
import AppKit
import OSLog

struct SmartStatusText: View {
    let candidates: [String]
    let autoWidth: Bool
    let userWidthPt: CGFloat?
    let iconWidth: CGFloat
    
    @State private var selectedCandidate: String = "•"
    @State private var budget: CGFloat = 120.0
    @State private var updateTrigger = false
    
    private let appSettings = AppSettings.shared
    private let logger = Logger(subsystem: "org.romancha.timelymeet", category: "SmartStatusText")
    
    init(candidates: [String], autoWidth: Bool, userWidthPt: CGFloat?, iconWidth: CGFloat = 0) {
        self.candidates = candidates
        self.autoWidth = autoWidth
        self.userWidthPt = userWidthPt
        self.iconWidth = iconWidth
    }
    
    var body: some View {
        Text(selectedCandidate)
            .font(.system(size: 12, weight: .medium))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.9)
            .truncationMode(.middle)
            .frame(width: max(1, budget), alignment: .trailing)
            .onAppear {
                updateCandidate()
            }
            .onChange(of: candidates) { _, newCandidates in
                logger.debug("Candidates changed to \(newCandidates)")
                updateCandidate()
            }
            .onChange(of: autoWidth) { _, _ in
                updateCandidate()
            }
            .onChange(of: userWidthPt) { _, _ in
                updateCandidate()
            }
            .id(candidates.joined(separator: "|")) // Force re-render when candidates change
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    updateCandidate()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSLocale.currentLocaleDidChangeNotification)) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    updateCandidate()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSSystemClockDidChange)) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    updateCandidate()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    updateCandidate()
                }
            }
    }
    
    
    private func updateCandidate() {
        DispatchQueue.main.async {
            // Calculate budget
            let newBudget = calculateBudget()
            self.budget = newBudget
            
            // Select best candidate
            let bestCandidate = selectBestCandidate(for: newBudget)
            
            // Log if candidate changed
            if self.selectedCandidate != bestCandidate {
                self.logCandidateSelection(budget: newBudget, candidate: bestCandidate)
            }
            
            self.selectedCandidate = bestCandidate
        }
    }
    
    private func calculateBudget() -> CGFloat {
        let totalBudget: CGFloat
        if autoWidth {
            totalBudget = calculateAutoBudget()
        } else {
            totalBudget = clamp(userWidthPt ?? 120.0, min: appSettings.menuBarMinBudget, max: appSettings.menuBarMaxBudget)
        }
        
        // Subtract the width of the icon and the space between the icon and the text.
        let textBudget = totalBudget - iconWidth - 4 // 4pt indent between icon and text
        return max(20.0, textBudget)
    }
    
    private func calculateAutoBudget() -> CGFloat {
        guard let screen = NSScreen.main else { return 120.0 }
        let screenWidth = screen.frame.width
        
        logger.debug("Auto-width calculation: Screen width is \(screenWidth)pt")
        
        // Adaptive budget calculation based on screen width ranges
        let calculatedBudget: CGFloat
        switch screenWidth {
        case ..<1200:
            calculatedBudget = screenWidth * 0.03
        case 1200..<1750:
            calculatedBudget = screenWidth * 0.05
        case 1750..<2000:
            calculatedBudget = screenWidth * 0.07
        case 2000..<4000:
            calculatedBudget = screenWidth * 0.12
        default:
            calculatedBudget = screenWidth * 0.15
        }
        
        return clamp(calculatedBudget, min: appSettings.menuBarMinBudget, max: appSettings.menuBarMaxBudget)
    }
    
    private func selectBestCandidate(for budget: CGFloat) -> String {
        guard !candidates.isEmpty else { 
            logger.debug("Candidate selection: No candidates available, fallback to '•'")
            return "•" 
        }
        
        logger.debug("Candidate selection process: Available budget: \(budget)pt, Total candidates: \(candidates.count)")
        
        for (index, candidate) in candidates.enumerated() {
            let candidateWidth = TextMeasurer.width(candidate)
            let fits = candidateWidth <= budget
            logger.debug("[\(index)] \"\(candidate)\" -> \(candidateWidth)pt (\(fits ? "FITS" : "too wide"))")
            
            if fits {
                logger.debug("Selected candidate [\(index)]: \"\(candidate)\"")
                return candidate
            }
        }
        
        let fallback = candidates.last ?? "•"
        logger.debug("No candidates fit in budget, using fallback: \"\(fallback)\"")
        return fallback
    }
    
    private func logCandidateSelection(budget: CGFloat, candidate: String) {
        let candidateIndex = candidates.firstIndex(of: candidate) ?? -1
        let textWidth = TextMeasurer.width(candidate)
        let locale = Locale.current.identifier
        let screenScale = NSScreen.main?.backingScaleFactor ?? 1.0
        let screenWidth = NSScreen.main?.frame.width ?? 0
        
        logger.debug("Final status bar state: Selected: [\(candidateIndex)] \"\(candidate)\", Budget: \(budget)pt, Text width: \(textWidth)pt, Environment: locale=\(locale), scale=\(screenScale)x, screen_width=\(screenWidth)pt")
    }
    
    private func clamp(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        return Swift.max(min, Swift.min(max, value))
    }
}

// MARK: - Preview
#Preview {
    let candidates = ["1h 25m — Daily Standup (Zoom)", "1h 25m — Daily Standup", "1h 25m", "•"]
    
    VStack(spacing: 20) {
        SmartStatusText(candidates: candidates, autoWidth: true, userWidthPt: nil, iconWidth: 16)
            .background(Color.gray.opacity(0.2))
        
        SmartStatusText(candidates: candidates, autoWidth: false, userWidthPt: 100, iconWidth: 16)
            .background(Color.gray.opacity(0.2))
        
        SmartStatusText(candidates: candidates, autoWidth: false, userWidthPt: 60, iconWidth: 16)
            .background(Color.gray.opacity(0.2))
    }
    .padding()
}
