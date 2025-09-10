//
//  PerformanceMonitor.swift
//  TimelyMeet
//
//  
//

import Foundation
import OSLog
import os.signpost

@MainActor
class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()
    
    private let logger = Logger(subsystem: "org.romancha.timelymeete", category: "Performance")
    private let signposter = OSSignposter(logger: Logger(subsystem: "org.romancha.timelymeet", category: "Signpost"))
    
    @Published var memoryUsage: Double = 0.0
    @Published var cpuUsage: Double = 0.0
    @Published var isMonitoring = false
    
    private var monitoringTimer: Timer?
    private var signpostStates: [String: OSSignpostIntervalState] = [:]
    
    private init() {
        // Only start monitoring if developer mode and performance monitoring are enabled
        if DeveloperModeService.shared.isDevModeEnabled && DeveloperModeService.shared.isPerformanceMonitoringEnabled {
            startMonitoring()
        }
    }
    
    deinit {
        Task { @MainActor in
            stopMonitoring()
        }
    }
    
    // MARK: - Monitoring Control
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        guard DeveloperModeService.shared.isDevModeEnabled && DeveloperModeService.shared.isPerformanceMonitoringEnabled else { 
            logger.info("Performance monitoring disabled - developer mode or performance monitoring not enabled")
            return 
        }
        
        isMonitoring = true
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateMetrics()
            }
        }
        
        logger.info("Performance monitoring started")
    }
    
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        isMonitoring = false
        
        logger.info("Performance monitoring stopped")
    }
    
    func toggleMonitoringBasedOnDevMode() {
        if DeveloperModeService.shared.isDevModeEnabled && DeveloperModeService.shared.isPerformanceMonitoringEnabled {
            if !isMonitoring {
                startMonitoring()
            }
        } else {
            if isMonitoring {
                stopMonitoring()
            }
        }
    }
    
    // MARK: - Performance Measurements
    
    func beginSignpost(_ name: String) -> OSSignpostID {
        let signpostID = signposter.makeSignpostID()
        let state = signposter.beginInterval("Performance Operation", id: signpostID, "\(name)")
        signpostStates[name] = state
        
        logger.debug("Started signpost: \(name)")
        return signpostID
    }
    
    func endSignpost(_ name: String, id: OSSignpostID) {
        if let state = signpostStates.removeValue(forKey: name) {
            signposter.endInterval("Performance Operation", state)
            logger.debug("Ended signpost: \(name)")
        }
    }
    
    func measureBlock<T>(_ name: String, block: () throws -> T) rethrows -> T {
        // If developer mode or performance monitoring is disabled, just execute the block without measurement
        guard DeveloperModeService.shared.isDevModeEnabled && DeveloperModeService.shared.isPerformanceMonitoringEnabled else {
            return try block()
        }
        
        let signpostID = beginSignpost(name)
        defer { endSignpost(name, id: signpostID) }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        if timeElapsed > 0.1 { // Log operations taking more than 100ms
            logger.warning("Slow operation '\(name)' took \(timeElapsed * 1000, privacy: .public)ms")
        }
        
        return result
    }
    
    func measureAsyncBlock<T>(_ name: String, block: () async throws -> T) async rethrows -> T {
        // If developer mode or performance monitoring is disabled, just execute the block without measurement
        guard DeveloperModeService.shared.isDevModeEnabled && DeveloperModeService.shared.isPerformanceMonitoringEnabled else {
            return try await block()
        }
        
        let signpostID = beginSignpost(name)
        defer { endSignpost(name, id: signpostID) }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await block()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        if timeElapsed > 0.1 {
            logger.warning("Slow async operation '\(name)' took \(timeElapsed * 1000, privacy: .public)ms")
        }
        
        return result
    }
    
    // MARK: - Memory Management
    
    func checkForMemoryLeaks() {
        let memoryInfo = getMemoryUsage()
        
        if memoryInfo.resident > 100_000_000 { // 100MB threshold
            logger.warning("High memory usage detected: \(memoryInfo.resident / 1_000_000)MB resident, \(memoryInfo.virtual / 1_000_000)MB virtual")
        }
        
        // Check for potential retain cycles by monitoring object counts
        let objectCount = getApproximateObjectCount()
        if objectCount > 10000 {
            logger.warning("High object count detected: \(objectCount) objects")
        }
    }
    
    private func getMemoryUsage() -> (resident: Int, virtual: Int) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else {
            return (0, 0)
        }
        
        return (resident: Int(info.resident_size), virtual: Int(info.virtual_size))
    }
    
    private func getApproximateObjectCount() -> Int {
        // This is a rough estimate - in production, you might use more sophisticated profiling
        let memoryInfo = getMemoryUsage()
        return memoryInfo.resident / 1000 // Very rough estimate
    }
    
    private func updateMetrics() async {
        let memoryInfo = getMemoryUsage()
        memoryUsage = Double(memoryInfo.resident) / 1_000_000 // Convert to MB
        
        // Update CPU usage (simplified - in production use more accurate measurement)
        cpuUsage = getCurrentCPUUsage()
        
        checkForMemoryLeaks()
    }
    
    private func getCurrentCPUUsage() -> Double {
        var info = processor_info_array_t(bitPattern: 0)
        var numCpuInfo = mach_msg_type_number_t(0)
        var numCpus = natural_t(0)
        
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCpus, &info, &numCpuInfo)
        
        guard result == KERN_SUCCESS else {
            return 0.0
        }
        
        // Simplified CPU calculation - return a rough estimate
        return Double.random(in: 0...10) // Placeholder - real implementation would calculate actual CPU usage
    }
    
    // MARK: - Performance Recommendations
    
    func getPerformanceRecommendations() -> [String] {
        var recommendations: [String] = []
        
        if memoryUsage > 50.0 {
            recommendations.append("Consider reducing memory usage - currently using \(String(format: "%.1f", memoryUsage))MB")
        }
        
        if cpuUsage > 20.0 {
            recommendations.append("High CPU usage detected - consider optimizing background tasks")
        }
        
        return recommendations
    }
    
    // MARK: - Debug Information
    
    func generatePerformanceReport() -> String {
        let memoryInfo = getMemoryUsage()
        
        return """
        Performance Report - \(Date())
        Memory Usage: \(String(format: "%.1f", memoryUsage))MB
        CPU Usage: \(String(format: "%.1f", cpuUsage))%
        Resident Memory: \(memoryInfo.resident / 1_000_000)MB
        Virtual Memory: \(memoryInfo.virtual / 1_000_000)MB
        Active Signposts: \(signpostStates.count)
        Recommendations: \(getPerformanceRecommendations().joined(separator: ", "))
        """
    }
}
