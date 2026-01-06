//
//  UnlimitedUpgradeSheet.swift
//  CarbFinder
//
//  Created for upgrading from Standard to Unlimited plan
//  Rule: General Coding - Beautiful, professional design matching IntroOfferSheet style
//  Rule: Subscriptions - Highlight Unlimited plan with introductory pricing
//

import SwiftUI
import StoreKit

/// Sheet shown when upgrading from Standard to Unlimited plan
/// Rule: General Coding - Matches IntroOfferSheet design but focuses only on Unlimited
/// Rule: Visual Design - White/black header with gold sparkle badge
struct UnlimitedUpgradeSheet: View {
    
    // MARK: - Properties
    
    /// Binding to control sheet presentation
    /// Rule: State Management - Use @Binding for sheet dismissal
    @Binding var isPresented: Bool
    
    /// Unlimited subscription product
    /// Rule: Subscriptions - Load unlimited product for promotional view
    @State private var unlimitedProduct: Product?
    
    /// Environment for color scheme detection
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Constants
    
    /// Product ID for Unlimited subscription
    private let unlimitedProductID = "unlimited"
    
    /// Button color (solid, no gradient)
    /// Rule: Visual Design - Button uses main blue color matching IntroOfferSheet
    private let buttonColor = Color(red: 0x0b/255.0, green: 0x6d/255.0, blue: 0xd1/255.0) // #0b6dd1
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background color - adaptive for light/dark mode
            (colorScheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Top Section: White/Black Header (50% of sheet)
                ZStack(alignment: .top) {
                    // Background color (no gradient, just solid)
                    (colorScheme == .dark ? Color.black : Color.white)
                        .ignoresSafeArea(edges: .top)
                    
                    // Content
                    VStack(spacing: 12) {
                        Spacer()
                        
                        // Logo
                        VStack(spacing: 8) {
                            Image("logo")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 65)
                                .padding(.bottom, 8)
                        }
                        
                        // Large bold text: Main offer (dynamic from StoreKit)
                        // Rule: Subscriptions - Pull actual intro offer price and currency from App Store Connect
                        // Rule: Visual Design - Two-line style with "Unlimited" large and price smaller/gray
                        if let product = unlimitedProduct,
                           let introOffer = product.subscription?.introductoryOffer {
                            VStack(spacing: 4) {
                                Text("Unlimited")
                                    .font(.system(size: 40, weight: .heavy))
                                    .foregroundColor(.primary)
                                
                                Text("only \(introOffer.displayPrice)/month")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundColor(.secondary.opacity(0.85))
                            }
                            .multilineTextAlignment(.center)
                        } else if let product = unlimitedProduct {
                            // Fallback: Show regular price if no intro offer
                            VStack(spacing: 4) {
                                Text("Unlimited")
                                    .font(.system(size: 40, weight: .heavy))
                                    .foregroundColor(.primary)
                                
                                Text("only \(product.displayPrice)/month")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundColor(.secondary.opacity(0.85))
                            }
                            .multilineTextAlignment(.center)
                        } else {
                            // Loading state
                            Text("Get Unlimited")
                                .font(.system(size: 40, weight: .heavy))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                        }
                        
                        // Subtitle with offer duration
                        Text("three month offer.")
                            .font(.body)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 20)
                }
                .frame(height: UIScreen.main.bounds.height * 0.50)
                
                // MARK: - Middle Section: Benefits & Pricing
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Gray box containing benefit text
                    VStack(spacing: 12) {
                        // Primary benefit text
                        Text("Unlimited daily analyses for meals and recipes.")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        // Disclaimer text
                        Text("Offer valid for new customers.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 40)
                    .padding(.horizontal, 28)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.secondary.opacity(colorScheme == .dark ? 0.2 : 0.15))
                    )
                    .padding(.horizontal, 24)
                    
                    Spacer()
                        .frame(maxHeight: 20)
                    
                    // MARK: - Bottom Section: Button
                    VStack(spacing: 4) {
                        // Secondary pricing text
                        if let product = unlimitedProduct,
                           let introOffer = product.subscription?.introductoryOffer {
                            Text(formatIntroductoryOffer(product: product, introOffer: introOffer))
                                .font(.footnote)
                                .foregroundColor(.secondary.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                                .padding(.bottom, 12)
                        } else if let product = unlimitedProduct {
                            // Fallback
                            Text("Subscribe for \(product.displayPrice)/Month")
                                .font(.footnote)
                                .foregroundColor(.secondary.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                                .padding(.bottom, 12)
                        } else {
                            // Loading state
                            ProgressView()
                                .progressViewStyle(.circular)
                                .padding(.bottom, 12)
                        }
                        
                        // "Upgrade Now" button
                        Button {
                            print("[UnlimitedUpgradeSheet] Upgrade Now tapped")
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            upgradeToUnlimited()
                        } label: {
                            Text("Upgrade Now")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(buttonColor)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(unlimitedProduct == nil)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
            }
            
            // MARK: - Close Button (Absolute Top-Right)
            // Rule: Visual Design - Close button in ABSOLUTE top-right corner, independent of content
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Spacer()
                    
                    Button {
                        print("[UnlimitedUpgradeSheet] Close button tapped")
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(width: 32, height: 32)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
                .padding(.top, 16)
                .padding(.trailing, 16)
                
                Spacer()
            }
            .zIndex(999)
        }
        .onAppear {
            // Rule: Subscriptions - Load product on appear to get actual pricing
            loadProduct()
        }
        .onInAppPurchaseCompletion { product, result in
            // Rule: Subscriptions - Handle purchase completion
            if case .success(.success(let verificationResult)) = result {
                switch verificationResult {
                case .verified(let transaction):
                    print("[UnlimitedUpgradeSheet] Purchase successful: \(transaction.productID)")
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    // Dismiss sheet after successful purchase
                    isPresented = false
                case .unverified(_, let error):
                    print("[UnlimitedUpgradeSheet] Purchase unverified: \(error)")
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Load the Unlimited subscription product from StoreKit
    /// Rule: Subscriptions - Fetch product to show actual pricing
    private func loadProduct() {
        Task {
            do {
                let products = try await Product.products(for: [unlimitedProductID])
                
                await MainActor.run {
                    // Find and assign Unlimited product
                    if let unlimited = products.first(where: { $0.id == unlimitedProductID }) {
                        unlimitedProduct = unlimited
                        print("[UnlimitedUpgradeSheet] Loaded Unlimited product: \(unlimited.displayName) - \(unlimited.displayPrice)")
                        
                        if let intro = unlimited.subscription?.introductoryOffer {
                            print("[UnlimitedUpgradeSheet] Unlimited introductory offer: \(intro.displayPrice)")
                        }
                    } else {
                        print("[UnlimitedUpgradeSheet] ⚠️ Unlimited product not found")
                    }
                }
            } catch {
                print("[UnlimitedUpgradeSheet] ❌ Failed to load product: \(error)")
            }
        }
    }
    
    /// Format the introductory offer text dynamically from StoreKit
    /// Rule: Subscriptions - Show actual pricing from App Store Connect
    /// Rule: Visual Design - Use "/Month" format instead of "/month"
    private func formatIntroductoryOffer(product: Product, introOffer: Product.SubscriptionOffer) -> String {
        // Get intro offer details
        let introPriceString = introOffer.displayPrice
        let regularPriceString = product.displayPrice
        
        // Calculate duration in months
        let period = introOffer.period
        let periodValue = period.value
        
        // Format based on period unit
        let durationText: String
        switch period.unit {
        case .month:
            durationText = periodValue == 1 ? "1 month" : "\(periodValue) months"
        case .year:
            durationText = periodValue == 1 ? "1 year" : "\(periodValue) years"
        case .week:
            durationText = periodValue == 1 ? "1 week" : "\(periodValue) weeks"
        case .day:
            durationText = periodValue == 1 ? "1 day" : "\(periodValue) days"
        @unknown default:
            durationText = "\(periodValue) periods"
        }
        
        // Build the pricing text with "/Month" format
        // Example: "3 months for 0.99€/Month, then 4.49€/Month"
        return "\(durationText) for \(introPriceString)/Month, then \(regularPriceString)/Month"
    }
    
    /// Initiate purchase of Unlimited subscription
    /// Rule: Subscriptions - Use StoreKit 2 purchase flow
    private func upgradeToUnlimited() {
        guard let product = unlimitedProduct else {
            print("[UnlimitedUpgradeSheet] ⚠️ Cannot purchase - unlimited product not loaded")
            return
        }
        
        Task {
            do {
                print("[UnlimitedUpgradeSheet] Starting purchase for: \(product.displayName)")
                let result = try await product.purchase()
                
                switch result {
                case .success(let verification):
                    let transaction = try checkVerified(verification)
                    print("[UnlimitedUpgradeSheet] ✅ Purchase successful: \(transaction.productID)")
                    await transaction.finish()
                    
                    // Success handled by onInAppPurchaseCompletion modifier
                    
                case .userCancelled:
                    print("[UnlimitedUpgradeSheet] User cancelled purchase")
                    
                case .pending:
                    print("[UnlimitedUpgradeSheet] Purchase pending (Ask to Buy)")
                    
                @unknown default:
                    print("[UnlimitedUpgradeSheet] Unknown purchase result")
                }
            } catch {
                print("[UnlimitedUpgradeSheet] ❌ Purchase failed: \(error)")
            }
        }
    }
    
    /// Verify a transaction result
    /// Rule: Security - Always verify transactions to prevent fraud
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            print("[UnlimitedUpgradeSheet] Transaction verification failed")
            throw NSError(domain: "UnlimitedUpgradeSheet", code: 1, userInfo: [NSLocalizedDescriptionKey: "Transaction verification failed"])
        case .verified(let safe):
            return safe
        }
    }
}

// MARK: - Preview

#Preview("Unlimited Upgrade Sheet") {
    UnlimitedUpgradeSheet(isPresented: .constant(true))
}
