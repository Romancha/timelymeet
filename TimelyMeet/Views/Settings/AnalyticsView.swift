//
//  AnalyticsView.swift
//  TimelyMeet
//
//  
//

import SwiftUI

struct AnalyticsView: View {
    @EnvironmentObject private var analyticsService: MeetingAnalyticsService
    @State private var weeklyReport: WeeklyAnalyticsReport?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("meeting_analytics_title".localized())
                .font(.title2)
                .fontWeight(.bold)
            
            GroupBox("success_metrics_title".localized()) {
                VStack(alignment: .leading, spacing: 12) {
                    MetricRow(
                        title: "join_success_rate_title".localized(),
                        value: "\(Int(analyticsService.getJoinSuccessRate() * 100))%",
                        icon: "checkmark.circle"
                    )
                    
                    MetricRow(
                        title: "notification_engagement_title".localized(),
                        value: "\(Int(analyticsService.getNotificationEngagementRate() * 100))%",
                        icon: "bell.badge"
                    )
                    
                    MetricRow(
                        title: "fullscreen_effectiveness_title".localized(),
                        value: "\(Int(analyticsService.getFullscreenEffectiveness() * 100))%",
                        icon: "rectangle.expand.vertical"
                    )
                }
            }
            
            GroupBox("platform_reliability_title".localized()) {
                VStack(alignment: .leading, spacing: 8) {
                    let reliablePlatforms = analyticsService.getMostReliablePlatforms()
                    
                    ForEach(Array(reliablePlatforms.enumerated()), id: \.offset) { index, platformData in
                        let (platform, successRate) = platformData
                        
                        HStack {
                            Image(systemName: platform.iconName)
                                .foregroundColor(.blue)
                            
                            Text(platform.rawValue)
                            
                            Spacer()
                            
                            Text("\(Int(successRate * 100))%")
                                .fontWeight(.medium)
                                .foregroundColor(successRate > 0.8 ? .green : successRate > 0.6 ? .orange : .red)
                        }
                    }
                    
                    if reliablePlatforms.isEmpty {
                        Text("no_platform_data_message".localized())
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
            }
            
            if let report = weeklyReport {
                GroupBox("weekly_summary_title".localized()) {
                    VStack(alignment: .leading, spacing: 8) {
                        MetricRow(title: "total_notifications_title".localized(), value: "\(report.totalNotifications)", icon: "bell")
                        MetricRow(title: "successful_joins_title".localized(), value: "\(report.successfulJoins)", icon: "checkmark")
                        MetricRow(title: "average_response_time_title".localized(), value: "\(Int(report.averageResponseTime))s", icon: "clock")
                    }
                }
            }
        }
        .onAppear {
            weeklyReport = analyticsService.generateWeeklyReport()
        }
    }
}

struct MetricRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
            
            Text(title)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
        }
    }
}