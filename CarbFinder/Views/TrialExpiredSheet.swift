//
//  TrialExpiredSheet.swift
//  CarbFinder
//
//  Created by Diego Szekely on 16.12.25.
//

import SwiftUI
import StoreKit

/// Beautiful sheet shown when user's trial expires and they attempt to capture
/// Rule: General Coding - Clear communication with user about trial status
/// Rule: Subscriptions - Direct access to subscription options via StoreKit 2
/// Rule: General Coding - Matches existing SubscriptionStoreSheet design for consistency
struct TrialExpiredSheet: View {
    
    // MARK: - Properties
    
    /// Binding to control sheet presentation
    /// Rule: State Management - Use @Binding for sheet dismissal
    @Binding var isPresented: Bool
    
    /// Track current color scheme for conditional styling
    /// Rule: General Coding - Optimize for both light AND dark mode
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Body
    
    var body: some View {
        SubscriptionStoreView(
            productIDs: ["PremiumStandardSub", "unlimited"],
            marketingContent: {
                // MARK: - Header Content
                // Rule: General Coding - Match existing SubscriptionStoreSheet layout
                // Rule: Visual Design - Light mode: Dark blue background with white text
                // Rule: Visual Design - Dark mode: No background, primary text color
                ZStack {
                    // Dark blue background - ONLY in light mode
                    // Rule: General Coding - Optimize for both light AND dark mode
                    if colorScheme == .light {
                        Color(red: 0x0F/255.0, green: 0x3D/255.0, blue: 0x66/255.0) // #0F3D66
                            .ignoresSafeArea()
                    }
                    
                    // Text content
                    VStack(alignment: .leading, spacing: 12) {
                        
                        // 1. Top Spacer: Pushes text towards the middle
                        Spacer()
                        
                        // Tagline with "Your free trial has ended" message
                        // Rule: General Coding - Use simple text for trial expiration message
                        // Rule: Visual Design - Light mode: White text on blue, Dark mode: Primary color text
                        Text("Your free trial has ended")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(colorScheme == .light ? .white : .primary)
                            .multilineTextAlignment(.leading)
                        
                        // Subtitle text
                        // Rule: General Coding - Match existing subtitle style
                        // Rule: Visual Design - Light mode: White text on blue, Dark mode: Primary color text
                        Text("Subscribe to continue using Carbetic")
                            .font(.headline)
                            .foregroundColor(colorScheme == .light ? .white.opacity(0.9) : .primary.opacity(0.8))
                        
                        // 2. Bottom Spacer: Balances the text
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        )
        // MARK: - The "Swoosh" / Sticky Bottom Logic
        // Rule: Subscriptions - Use prominent picker style like existing sheet
        .subscriptionStoreControlStyle(.prominentPicker)
        
        // MARK: - Visual Styling
        // Rule: Visual Design - Light mode: Dark blue accent (#0F3D66), Dark mode: System accent (light blue)
        // Rule: General Coding - Optimize for both light AND dark mode
        .tint(colorScheme == .light ? Color(red: 0x0F/255.0, green: 0x3D/255.0, blue: 0x66/255.0) : nil)
        
        // MARK: - Hide Restore Button
        // Rule: General Coding - Match existing sheet by hiding restore button
        .storeButton(.hidden, for: .restorePurchases)
        
        // MARK: - Purchase Logic
        // Rule: Subscriptions - Handle successful purchase and auto-dismiss
        .onInAppPurchaseCompletion { product, result in
            print("[TrialExpiredSheet] Purchase completion: \(product.id)")
            
            if case .success(.success(let verificationResult)) = result {
                switch verificationResult {
                case .verified(let transaction):
                    print("[TrialExpiredSheet] Purchase verified: \(transaction.productID)")
                    // Rule: General Coding - Haptic feedback for successful purchase
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    // Dismiss sheet automatically after successful purchase
                    isPresented = false
                    
                case .unverified(_, let error):
                    print("[TrialExpiredSheet] Purchase unverified: \(error)")
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Trial Expired Sheet") {
    // Rule: SwiftUI-specific Patterns - Preview with constant binding
    TrialExpiredSheet(isPresented: .constant(true))
}
