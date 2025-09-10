//
//  MemoryLeakDetector.swift
//  TimelyMeet
//
//  
//

import Foundation
import OSLog
import SwiftUI

@MainActor
class MemoryLeakDetector: ObservableObject {
    static let shared = MemoryLeakDetector()
    
    @Published var isMonitoring = false
    @Published var memoryWarnings: [MemoryWarning] = []
    @Published var objectCountHistory: [ObjectCountSnapshot] = []
    
    private let logger = Logger(subsystem: "org.romancha.timelymeet", category: "MemoryLeakDetector")
    private var monitoringTimer: Timer?
    private var baselineMemory: UInt64 = 0
    private var objectRegistry: [String: WeakObjectSet] = [:]
    
    private let memoryThreshold: UInt64 = 100_000_000 // 100MB
    private let objectCountThreshold: Int = 1000
    private let monitoringInterval: TimeInterval = 10.0 // 10 seconds
    
    private init() {}
    
    // MARK: - Monitoring Control
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        baselineMemory = getCurrentMemoryUsage()
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performMemoryCheck()
            }
        }
        
        logger.info("Memory leak monitoring started with baseline: \(self.baselineMemory / 1024 / 1024)MB")
    }
    
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        isMonitoring = false
        
        logger.info("Memory leak monitoring stopped")
    }
    
    // MARK: - Object Tracking
    
    func registerObject<T: AnyObject>(_ object: T, category: String = "General") {
        if objectRegistry[category] == nil {
            objectRegistry[category] = WeakObjectSet()
        }
        objectRegistry[category]?.add(object)
        
        logger.debug("Registered object of type \(String(describing: T.self)) in category \(category)")
    }
    
    func unregisterObject<T: AnyObject>(_ object: T, category: String = "General") {
        objectRegistry[category]?.remove(object)
        logger.debug("Unregistered object of type \(String(describing: T.self)) from category \(category)")
    }
    
    // MARK: - Memory Analysis
    
    private func performMemoryCheck() {
        let currentMemory = getCurrentMemoryUsage()
        let memoryGrowth = currentMemory - baselineMemory
        
        // Check for significant memory growth
        if memoryGrowth > memoryThreshold {
            let warning = MemoryWarning(
                type: .excessiveGrowth,
                message: "Memory usage increased by \(memoryGrowth / 1024 / 1024)MB from baseline",
                currentMemory: currentMemory,
                timestamp: Date()
            )
            
            addMemoryWarning(warning)
        }
        
        // Check object counts
        analyzeObjectCounts()
        
        // Create snapshot for history
        let snapshot = ObjectCountSnapshot(
            timestamp: Date(),
            memoryUsage: currentMemory,
            objectCounts: getObjectCounts()
        )
        
        objectCountHistory.append(snapshot)
        
        // Keep only last 50 snapshots
        if objectCountHistory.count > 50 {
            objectCountHistory.removeFirst()
        }
        
        // Perform detailed analysis if memory is high
        if currentMemory > memoryThreshold * 2 {
            performDetailedAnalysis()
        }
    }
    
    private func analyzeObjectCounts() {
        cleanupObjectRegistry()
        
        for (category, objectSet) in objectRegistry {
            let count = objectSet.count
            if count > objectCountThreshold {
                let warning = MemoryWarning(
                    type: .highObjectCount,
                    message: "High object count in \(category): \(count) objects",
                    currentMemory: getCurrentMemoryUsage(),
                    timestamp: Date()
                )
                
                addMemoryWarning(warning)
            }
        }
    }
    
    private func performDetailedAnalysis() {
        logger.warning("Performing detailed memory analysis due to high memory usage")
        
        // Analyze memory patterns
        if objectCountHistory.count >= 5 {
            let recentSnapshots = Array(objectCountHistory.suffix(5))
            let memoryTrend = analyzeMemoryTrend(recentSnapshots)
            
            if memoryTrend > 0.1 { // 10% growth trend
                let warning = MemoryWarning(
                    type: .continuousGrowth,
                    message: "Continuous memory growth detected: \(String(format: "%.1f", memoryTrend * 100))% increase",
                    currentMemory: getCurrentMemoryUsage(),
                    timestamp: Date()
                )
                
                addMemoryWarning(warning)
            }
        }
        
        // Suggest potential solutions
        generateMemoryOptimizationSuggestions()
    }
    
    private func analyzeMemoryTrend(_ snapshots: [ObjectCountSnapshot]) -> Double {
        guard snapshots.count >= 2 else { return 0.0 }
        
        let firstMemory = Double(snapshots.first!.memoryUsage)
        let lastMemory = Double(snapshots.last!.memoryUsage)
        
        return (lastMemory - firstMemory) / firstMemory
    }
    
    private func generateMemoryOptimizationSuggestions() {
        var suggestions: [String] = []
        
        // Analyze object counts by category
        let sortedCategories = objectRegistry.sorted { $0.value.count > $1.value.count }
        
        if let topCategory = sortedCategories.first, topCategory.value.count > 500 {
            suggestions.append("Consider implementing object pooling for \(topCategory.key) objects")
        }
        
        if getCurrentMemoryUsage() > memoryThreshold * 3 {
            suggestions.append("Consider implementing lazy loading for large data sets")
            suggestions.append("Review image caching and consider memory-efficient formats")
        }
        
        if suggestions.isEmpty {
            suggestions.append("Monitor continued memory growth and consider profiling with Instruments")
        }
        
        logger.info("Memory optimization suggestions: \(suggestions.joined(separator: ", "))")
    }
    
    // MARK: - Utility Methods
    
    private func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? info.resident_size : 0
    }
    
    private func cleanupObjectRegistry() {
        for (_, objectSet) in objectRegistry {
            objectSet.cleanup()
        }
    }
    
    private func getObjectCounts() -> [String: Int] {
        return objectRegistry.mapValues { $0.count }
    }
    
    private func addMemoryWarning(_ warning: MemoryWarning) {
        memoryWarnings.append(warning)
        
        // Keep only last 20 warnings
        if memoryWarnings.count > 20 {
            memoryWarnings.removeFirst()
        }
        
        logger.warning("Memory warning: \(warning.message)")
        
        // Report critical warnings with higher log level
        if warning.type == .excessiveGrowth || warning.type == .continuousGrowth {
            let error = MemoryLeakError.potentialLeak(warning.message)
            logger.error("Memory Leak Detection: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Public Interface
    
    func generateMemoryReport() -> String {
        let currentMemory = getCurrentMemoryUsage()
        let memoryMB = currentMemory / 1024 / 1024
        
        let objectCounts = getObjectCounts()
        let totalObjects = objectCounts.values.reduce(0, +)
        
        let recentWarnings = memoryWarnings.suffix(5)
        
        return """
        Memory Report - \(Date())
        Current Memory Usage: \(memoryMB)MB
        Baseline Memory: \(baselineMemory / 1024 / 1024)MB
        Memory Growth: \(Int64(currentMemory) - Int64(baselineMemory))MB
        
        Object Counts by Category:
        \(objectCounts.map { "\($0.key): \($0.value)" }.joined(separator: "\n"))
        Total Tracked Objects: \(totalObjects)
        
        Recent Warnings:
        \(recentWarnings.map { "[\($0.timestamp)] \($0.message)" }.joined(separator: "\n"))
        """
    }
    
    func clearWarnings() {
        memoryWarnings.removeAll()
    }
    
    func resetBaseline() {
        baselineMemory = getCurrentMemoryUsage()
        logger.info("Memory baseline reset to: \(self.baselineMemory / 1024 / 1024)MB")
    }
}

// MARK: - Supporting Types

struct MemoryWarning: Identifiable {
    let id = UUID()
    let type: WarningType
    let message: String
    let currentMemory: UInt64
    let timestamp: Date
    
    enum WarningType {
        case excessiveGrowth
        case highObjectCount
        case continuousGrowth
    }
}

struct ObjectCountSnapshot {
    let timestamp: Date
    let memoryUsage: UInt64
    let objectCounts: [String: Int]
}

class WeakObjectSet {
    private var objects: [WeakObjectWrapper] = []
    
    var count: Int {
        cleanup()
        return objects.count
    }
    
    func add<T: AnyObject>(_ object: T) {
        cleanup()
        objects.append(WeakObjectWrapper(object))
    }
    
    func remove<T: AnyObject>(_ object: T) {
        cleanup()
        objects.removeAll { wrapper in
            wrapper.object === object
        }
    }
    
    func cleanup() {
        objects.removeAll { $0.object == nil }
    }
}

private class WeakObjectWrapper {
    weak var object: AnyObject?
    
    init(_ object: AnyObject) {
        self.object = object
    }
}

enum MemoryLeakError: Error, LocalizedError {
    case potentialLeak(String)
    case excessiveMemoryUsage(UInt64)
    
    var errorDescription: String? {
        switch self {
        case .potentialLeak(let description):
            return "Potential memory leak detected: \(description)"
        case .excessiveMemoryUsage(let bytes):
            return "Excessive memory usage: \(bytes / 1024 / 1024)MB"
        }
    }
}
