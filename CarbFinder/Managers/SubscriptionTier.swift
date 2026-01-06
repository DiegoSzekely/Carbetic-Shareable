//
//  SubscriptionTier.swift
//  CarbFinder
//
//  Defines subscription tiers and their daily capture limits
//  Rule: General Coding - Simple enum for clear tier management
//

import Foundation

/// Represents the user's current subscription tier
/// Rule: State Management - Enum for type-safe tier management
enum SubscriptionTier: String, Codable {
    case free = "Free"
    case premium = "Standard"
    case unlimited = "Unlimited"
    
    /// Daily capture limit for this tier
    /// Rule: General Coding - Centralized limit configuration
    var dailyCaptureLimit: Int {
        switch self {
        case .free:
            return 10 // Trial users: 10 captures/day
        case .premium:
            return 10 // Standard: 10 captures/day
        case .unlimited:
            return 50 // Unlimited: No limit shown to user (capped at 50 for fair usage)
        }
    }
    
    /// Product ID for this tier (nil for free)
    /// Rule: Subscriptions - Product IDs must match App Store Connect exactly
    var productID: String? {
        switch self {
        case .free:
            return nil
        case .premium:
            return "PremiumStandardSub"
        case .unlimited:
            return "unlimited"
        }
    }
    
    /// User-friendly display name
    var displayName: String {
        return self.rawValue
    }
    
    /// Short description of tier benefits
    var description: String {
        switch self {
        case .free:
            return "10 captures per day during trial"
        case .premium:
            return "10 captures per day for meal and recipe analysis"
        case .unlimited:
            return "Unlimited captures for meal and recipe analysis. Fair usage limits apply."
        }
    }
    
    /// Initialize from product ID
    /// Rule: General Coding - Robust initialization from StoreKit products
    init(productID: String) {
        print("[SubscriptionTier] Initializing tier from product ID: '\(productID)'")
        
        switch productID {
        case "PremiumStandardSub":
            self = .premium
            print("[SubscriptionTier] Mapped to: Standard")
        case "unlimited":
            self = .unlimited
            print("[SubscriptionTier] Mapped to: Unlimited")
        default:
            print("[SubscriptionTier] ⚠️ Unknown product ID: '\(productID)', defaulting to free")
            print("[SubscriptionTier] Expected: 'PremiumStandardSub' or 'unlimited'")
            self = .free
        }
    }
}
