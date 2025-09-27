//
//  MenuBarLabel.swift
//  TimelyMeet
//
//  Created by Roman Makarskiy on 10.09.2025.
//


import SwiftUI
import CoreData
import Foundation

struct MenuBarLabelView: View {
    @EnvironmentObject private var menuBarService: MenuBarService
    @EnvironmentObject private var appModel: AppModel
    private let appSettings = AppSettings.shared
    
    var body: some View {
        HStack() {
            if appModel.isInitialized && menuBarService.shouldShowMeetingInfo {
                Image(systemName: menuBarService.getMenuBarIcon())
                    .foregroundStyle(.primary)
                
                SmartStatusText(
                    candidates: generateCandidates(),
                    autoWidth: appSettings.statusBarAutoWidth,
                    userWidthPt: CGFloat(appSettings.statusBarWidthPt),
                    iconWidth: 16 // Icon width + padding
                )
            } else {
                Image(systemName: "calendar.circle")
                    .foregroundStyle(.primary)
            }
        }
        .frame(minWidth: 22)
        .padding(.leading, 2)
        .onAppear {
            if !appModel.isInitialized {
                Task {
                    await appModel.initialize()
                }
            }
        }
    }
    
    private func generateCandidates() -> [String] {
        guard let nextEvent = menuBarService.nextMeetingEvent else { return ["•"] }
        
        var candidates: [String] = []
        
        let showTime = appSettings.menuBarShowTime
        let showEventTitle = appSettings.menuBarShowEventTitle
        
        if !showTime && !showEventTitle {
            return ["•"]
        }
        
        let timeText = showTime ? formatTimeUntilMeeting(nextEvent.startDate) : ""
        let eventTitle = showEventTitle ? (nextEvent.title ?? "Meeting") : ""
        
        if showTime && showEventTitle {
            // Both parts: time and name
            let separator = " — "
            
            // Full title
            let fullTitle = "\(timeText)\(separator)\(eventTitle)"
            candidates.append(fullTitle)
            
            // Abbreviated title (first word)
            let shortTitle = eventTitle.components(separatedBy: " ").first ?? ""
            if shortTitle != eventTitle && !shortTitle.isEmpty {
                let truncatedTitle = String(shortTitle.prefix(30))
                candidates.append("\(timeText)\(separator)\(truncatedTitle)")
            }
            
            // Just time
            candidates.append(timeText)
            
        } else if showTime {
            // Just time
            candidates.append(timeText)
            
        } else if showEventTitle {
            // Just event name
            let truncatedTitle = String(eventTitle.prefix(30))
            candidates.append(truncatedTitle)
            
            // Shorter version
            if truncatedTitle.count > 10 {
                candidates.append(String(eventTitle.prefix(10)))
            }
        }
        
        // Fallback
        candidates.append("•")
        
        return candidates.uniqued()
    }
    
    private func formatTimeUntilMeeting(_ date: Date) -> String {
        let now = Date()
        let timeInterval = date.timeIntervalSince(now)
        
        if timeInterval < 0 {
            return "status_started".localized()
        } else if timeInterval < 60 {
            return "Now"
        } else if timeInterval < 3600 { // Less than 1 hour
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m"
        } else if timeInterval < 86400 { // Less than 24 hours
            let hours = Int(timeInterval / 3600)
            let minutes = Int((timeInterval.truncatingRemainder(dividingBy: 3600)) / 60)
            if minutes == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(minutes)m"
            }
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }
}


private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var set = Set<Element>()
        return filter { set.insert($0).inserted }
    }
}
