//
//  CaptureUsageManager.swift
//  CarbFinder
//
//  Tracks daily capture usage locally, resets at midnight local time
//  Rule: State Management - ObservableObject for reactive UI updates
//

import Foundation
import Combine // Rule: State Management - Combine required for ObservableObject
import SwiftUI

/// Manages daily capture usage tracking with local storage
/// Rule: Performance Optimization - Uses UserDefaults for lightweight local storage
final class CaptureUsageManager: ObservableObject {
    
    // MARK: - Properties
    
    /// Current date for tracking daily resets
    /// Rule: State Management - @Published for reactive updates
    @Published private(set) var currentDate: Date = Date()
    
    /// Number of captures used today
    /// Rule: State Management - @Published for reactive updates
    @Published private(set) var capturesUsedToday: Int = 0
    
    /// Last reset date (stored persistently)
    /// Rule: General Coding - Persist reset date to handle app restarts
    private var lastResetDate: Date? {
        get {
            UserDefaults.standard.object(forKey: "lastCaptureResetDate") as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "lastCaptureResetDate")
            print("[CaptureUsage] Last reset date saved: \(newValue?.formatted() ?? "nil")")
        }
    }
    
    /// Captures used count (stored persistently)
    /// Rule: General Coding - Persist usage count to handle app restarts
    private var storedCapturesUsed: Int {
        get {
            UserDefaults.standard.integer(forKey: "capturesUsedToday")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "capturesUsedToday")
            print("[CaptureUsage] Stored captures used: \(newValue)")
        }
    }
    
    // MARK: - Initialization
    
    init() {
        print("[CaptureUsage] Initializing...")
        
        // Load persisted values
        capturesUsedToday = storedCapturesUsed
        
        // Check if we need to reset (new day)
        checkAndResetIfNeeded()
        
        // Set up midnight reset timer
        setupMidnightResetTimer()
        
        print("[CaptureUsage] Initialized. Captures used today: \(capturesUsedToday)")
    }
    
    // MARK: - Public Methods
    
    /// Increments the capture count by 1
    /// Rule: General Coding - Simple, clear method for tracking usage
    func incrementCaptureCount() {
        capturesUsedToday += 1
        storedCapturesUsed = capturesUsedToday
        
        print("[CaptureUsage] Capture count incremented: \(capturesUsedToday)")
    }
    
    /// Checks if user has reached their daily limit
    /// Rule: General Coding - Centralized limit check logic
    func hasReachedLimit(tier: SubscriptionTier) -> Bool {
        let limit = tier.dailyCaptureLimit
        let reached = capturesUsedToday >= limit
        
        print("[CaptureUsage] Limit check: \(capturesUsedToday)/\(limit) used, reached: \(reached)")
        return reached
    }
    
    /// Remaining captures for the given tier
    /// Rule: General Coding - Helper for displaying usage statistics
    func remainingCaptures(tier: SubscriptionTier) -> Int {
        let limit = tier.dailyCaptureLimit
        let remaining = max(0, limit - capturesUsedToday)
        
        return remaining
    }
    
    /// Manually trigger a reset (for testing purposes)
    /// Rule: Testing - Provide manual reset for testing flows
    func manualReset() {
        print("[CaptureUsage] Manual reset triggered")
        resetCaptureCount()
    }
    
    /// Reset usage to a specific tier's limit on subscription upgrade
    /// Rule: General Coding - Better UX by giving user fresh start on upgrade
    func resetToTierLimit(tier: SubscriptionTier) {
        let limit = tier.dailyCaptureLimit
        capturesUsedToday = 0
        storedCapturesUsed = 0
        
        print("[CaptureUsage] Usage reset on upgrade to \(tier.displayName). New limit: \(limit)")
    }
    
    // MARK: - Private Methods
    
    /// Checks if it's a new day and resets if needed
    /// Rule: General Coding - Robust date comparison at calendar day level
    private func checkAndResetIfNeeded() {
        let calendar = Calendar.current
        let now = Date()
        
        // Get stored last reset date
        guard let lastReset = lastResetDate else {
            // First launch or no reset date stored
            print("[CaptureUsage] No last reset date found, setting to today")
            lastResetDate = now
            return
        }
        
        // Check if we're on a different calendar day
        let lastResetDay = calendar.startOfDay(for: lastReset)
        let todayDay = calendar.startOfDay(for: now)
        
        if todayDay > lastResetDay {
            print("[CaptureUsage] New day detected: \(lastResetDay.formatted()) → \(todayDay.formatted())")
            resetCaptureCount()
        } else {
            print("[CaptureUsage] Same day, no reset needed")
        }
    }
    
    /// Resets the capture count to 0
    /// Rule: General Coding - Centralized reset logic
    private func resetCaptureCount() {
        capturesUsedToday = 0
        storedCapturesUsed = 0
        lastResetDate = Date()
        
        print("[CaptureUsage] Capture count reset to 0")
    }
    
    /// Sets up a timer to reset at midnight local time
    /// Rule: General Coding - Automatic daily reset without user action
    private func setupMidnightResetTimer() {
        let calendar = Calendar.current
        let now = Date()
        
        // Calculate next midnight
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
              let nextMidnight = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: tomorrow) else {
            print("[CaptureUsage] Failed to calculate next midnight")
            return
        }
        
        let timeUntilMidnight = nextMidnight.timeIntervalSince(now)
        
        print("[CaptureUsage] Setting up midnight reset timer. Next reset in \(timeUntilMidnight/3600) hours")
        
        // Schedule timer for midnight
        Timer.scheduledTimer(withTimeInterval: timeUntilMidnight, repeats: false) { [weak self] _ in
            print("[CaptureUsage] Midnight timer fired - resetting capture count")
            self?.resetCaptureCount()
            
            // Reschedule for next midnight
            self?.setupMidnightResetTimer()
        }
    }
}
