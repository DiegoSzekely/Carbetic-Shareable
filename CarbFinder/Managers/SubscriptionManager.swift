//
//  SubscriptionManager.swift
//  CarbFinder
//
//  Manages StoreKit 2 subscription status and provides subscription tier
//  Rule: State Management - ObservableObject for reactive UI updates
//

import Foundation
import Combine // Rule: State Management - Combine required for ObservableObject
import StoreKit
import SwiftUI

/// Manages subscription state using StoreKit 2
/// Rule: Subscriptions - Use StoreKit 2 for modern subscription management
final class SubscriptionManager: ObservableObject {
    
    // MARK: - Properties
    
    /// Current subscription tier
    /// Rule: State Management - @Published for reactive updates
    @Published private(set) var currentTier: SubscriptionTier = .free
    
    /// Whether the manager is currently loading subscription status
    /// Rule: State Management - Loading state for UI feedback
    @Published private(set) var isLoading: Bool = true
    
    /// Available products from StoreKit
    /// Rule: Subscriptions - Store products for display in subscription UI
    @Published private(set) var availableProducts: [Product] = []
    
    /// Product IDs to fetch from StoreKit
    /// Rule: Subscriptions - Product IDs must match your .storekit file exactly
    private let productIDs: Set<String> = ["PremiumStandardSub", "unlimited"]
    
    /// Task for monitoring subscription updates
    /// Rule: State Management - Store task for proper cleanup
    private var updateListenerTask: Task<Void, Error>?
    
    /// Reference to usage manager for resetting usage on upgrade
    /// Rule: State Management - Weak reference to avoid retain cycle
    weak var usageManager: CaptureUsageManager?
    
    // MARK: - Initialization
    
    init() {
        print("[SubscriptionManager] Initializing...")
        
        // Start listening for subscription updates
        updateListenerTask = listenForTransactions()
        
        // Load initial subscription status
        Task {
            await loadProducts()
            await checkForUnfinishedTransactions()
            await updateSubscriptionStatus()
            
            await MainActor.run {
                isLoading = false
                print("[SubscriptionManager] Initialization complete. Current tier: \(currentTier.displayName)")
            }
        }
    }
    
    deinit {
        // Clean up transaction listener
        updateListenerTask?.cancel()
        print("[SubscriptionManager] Deinitialized")
    }
    
    // MARK: - Public Methods
    
    /// Purchase a subscription product
    /// Rule: Subscriptions - Handle purchase flow with proper error handling
    @MainActor
    func purchase(_ product: Product) async throws {
        print("[SubscriptionManager] Starting purchase for: \(product.displayName)")
        
        // Store the previous tier to detect upgrade
        let previousTier = currentTier
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            // Verify the transaction
            let transaction = try checkVerified(verification)
            
            print("[SubscriptionManager] Purchase successful: \(transaction.productID)")
            
            // Directly update tier from the purchased transaction
            let newTier = SubscriptionTier(productID: transaction.productID)
            currentTier = newTier
            print("[SubscriptionManager] Tier updated directly to: \(newTier.displayName)")
            
            // Reset usage count on upgrade for better UX
            // Rule: General Coding - Give user fresh start on upgrade
            if currentTier != previousTier {
                print("[SubscriptionManager] Tier upgraded from \(previousTier.displayName) to \(currentTier.displayName)")
                usageManager?.resetToTierLimit(tier: currentTier)
            }
            
            // Finish the transaction
            await transaction.finish()
            
            // Update subscription status for any other entitlements
            await updateSubscriptionStatus()
            
        case .userCancelled:
            print("[SubscriptionManager] User cancelled purchase")
            throw SubscriptionError.userCancelled
            
        case .pending:
            print("[SubscriptionManager] Purchase pending (Ask to Buy)")
            throw SubscriptionError.pending
            
        @unknown default:
            print("[SubscriptionManager] Unknown purchase result")
            throw SubscriptionError.unknown
        }
    }
    
    /// Restore purchases
    /// Rule: Subscriptions - Restore purchases for users who reinstalled
    @MainActor
    func restorePurchases() async throws {
        print("[SubscriptionManager] Restoring purchases...")
        
        try await AppStore.sync()
        await updateSubscriptionStatus()
        
        print("[SubscriptionManager] Purchases restored. Current tier: \(currentTier.displayName)")
    }
    
    // MARK: - Private Methods
    
    /// Check for unfinished transactions on app launch
    /// Rule: Subscriptions - CRITICAL for StoreKit - must handle unfinished transactions
    private func checkForUnfinishedTransactions() async {
        print("[SubscriptionManager] Checking for unfinished transactions...")
        
        var foundUnfinished = false
        
        // Check all unfinished transactions
        for await result in Transaction.unfinished {
            foundUnfinished = true
            
            do {
                let transaction = try checkVerified(result)
                
                print("[SubscriptionManager] Found unfinished transaction: \(transaction.productID)")
                
                // Finish the transaction
                await transaction.finish()
                print("[SubscriptionManager] Finished unfinished transaction: \(transaction.productID)")
                
            } catch {
                print("[SubscriptionManager] Failed to verify unfinished transaction: \(error)")
            }
        }
        
        if !foundUnfinished {
            print("[SubscriptionManager] No unfinished transactions found")
        }
    }
    
    /// Load available products from StoreKit
    /// Rule: Subscriptions - Fetch products for display in UI
    private func loadProducts() async {
        print("[SubscriptionManager] Loading products...")
        
        do {
            let products = try await Product.products(for: productIDs)
            
            await MainActor.run {
                // Sort products by price (ascending)
                self.availableProducts = products.sorted { $0.price < $1.price }
                print("[SubscriptionManager] Loaded \(products.count) products")
                
                for product in self.availableProducts {
                    print("  - \(product.displayName): \(product.displayPrice)")
                }
            }
        } catch {
            print("[SubscriptionManager] Failed to load products: \(error)")
        }
    }
    
    /// Update current subscription status by checking active entitlements
    /// Rule: Subscriptions - Trust StoreKit to provide the correct active subscription
    private func updateSubscriptionStatus() async {
        print("[SubscriptionManager] Checking subscription status...")
        
        var activeTier: SubscriptionTier = .free
        var foundEntitlement = false
        
        // StoreKit automatically provides the highest/current subscription in the group
        // We just need to check if there's an active entitlement
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                print("[SubscriptionManager] Found active entitlement: \(transaction.productID)")
                
                // Map product ID to tier - StoreKit already picked the right one
                activeTier = SubscriptionTier(productID: transaction.productID)
                foundEntitlement = true
                
                print("[SubscriptionManager] Active subscription tier: \(activeTier.displayName)")
                
                // Only process the first entitlement (there should only be one per subscription group)
                break
                
            } catch {
                print("[SubscriptionManager] Failed to verify transaction: \(error)")
            }
        }
        
        if !foundEntitlement {
            print("[SubscriptionManager] No active entitlements found - user is on free tier")
        }
        
        await MainActor.run {
            self.currentTier = activeTier
            print("[SubscriptionManager] Subscription status updated: \(activeTier.displayName)")
        }
    }
    
    /// Listen for transaction updates (purchases, renewals, expirations)
    /// Rule: Subscriptions - Monitor transactions for real-time updates
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            print("[SubscriptionManager] Starting transaction listener...")
            
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    
                    print("[SubscriptionManager] Transaction update: \(transaction.productID)")
                    
                    // Update subscription status
                    await self.updateSubscriptionStatus()
                    
                    // Finish the transaction
                    await transaction.finish()
                    
                } catch {
                    print("[SubscriptionManager] Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    /// Verify a transaction result
    /// Rule: Security - Always verify transactions to prevent fraud
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            print("[SubscriptionManager] Transaction verification failed")
            throw SubscriptionError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
}

// MARK: - Subscription Errors

/// Errors that can occur during subscription operations
/// Rule: General Coding - Proper error handling with descriptive errors
enum SubscriptionError: LocalizedError {
    case userCancelled
    case pending
    case verificationFailed
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .userCancelled:
            return "Purchase was cancelled"
        case .pending:
            return "Purchase is pending approval"
        case .verificationFailed:
            return "Failed to verify purchase"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}
