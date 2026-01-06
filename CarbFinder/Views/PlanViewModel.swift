//
//  PlanViewModel.swift
//  CarbFinder
//
//  Created by Diego Szekely on 13.11.25.
//

import Foundation

/// ViewModel for PlanView, managing subscription and trial state
/// Rule: State Management - @Observable for reactive state management
@Observable
final class PlanViewModel {
    
    // MARK: - Dependencies
    
    /// Manages installation date tracking for trial period
    let installationManager: UserInstallationManager
    
    /// Manages subscription status and StoreKit integration
    /// Rule: State Management - Dependency injection for subscription management
    let subscriptionManager: SubscriptionManager
    
    /// Manages daily capture usage tracking
    /// Rule: State Management - Dependency injection for usage tracking
    let usageManager: CaptureUsageManager
    
    // MARK: - Initialization
    
    /// Initialize with all required managers
    /// Rule: State Management - Dependency injection for testability
    init(installationManager: UserInstallationManager,
         subscriptionManager: SubscriptionManager,
         usageManager: CaptureUsageManager) {
        self.installationManager = installationManager
        self.subscriptionManager = subscriptionManager
        self.usageManager = usageManager
        print("[PlanViewModel] Initialized") // Rule: General Coding - Add debug logs
    }
    
    // MARK: - Computed Properties
    
    /// Whether to show the new user benefits banner
    var shouldShowTrialBanner: Bool {
        let show = installationManager.isWithinTrialPeriod()
        print("[PlanViewModel] Should show trial banner: \(show)") // Rule: General Coding - Add debug logs
        return show
    }
    
    /// Number of days remaining in trial
    var daysRemainingInTrial: Int {
        return installationManager.daysRemainingInTrial()
    }
    
    /// Whether any manager is still loading
    var isLoading: Bool {
        return installationManager.isLoading || subscriptionManager.isLoading
    }
    
    /// Current subscription tier
    var currentTier: SubscriptionTier {
        return subscriptionManager.currentTier
    }
    
    /// Captures used today
    var capturesUsedToday: Int {
        return usageManager.capturesUsedToday
    }
    
    /// Daily capture limit for current tier
    var dailyCaptureLimit: Int {
        return currentTier.dailyCaptureLimit
    }
    
    /// Remaining captures for today
    var remainingCaptures: Int {
        return usageManager.remainingCaptures(tier: currentTier)
    }
    
    /// Whether user has reached daily limit
    var hasReachedDailyLimit: Bool {
        return usageManager.hasReachedLimit(tier: currentTier)
    }
}
