//
//  IntroOfferSheet.swift
//  CarbFinder
//
//  Created for introductory offer presentation when trial expires
//  Rule: General Coding - Beautiful, professional design matching Apple Music style
//  Rule: Subscriptions - Highlight introductory offer for Standard plan
//

import SwiftUI
import StoreKit

/// Beautiful sheet shown when trial expires, highlighting the introductory offer
/// Rule: General Coding - Apple-inspired design with gradient header and clear value proposition
/// Rule: Visual Design - Two-stage presentation: compact "trial expired" → full offer details
struct IntroOfferSheet: View {
    
    // MARK: - Properties
    
    /// Binding to control sheet presentation
    /// Rule: State Management - Use @Binding for sheet dismissal
    @Binding var isPresented: Bool
    
    /// Skip the trial expired stage and show offer directly
    /// Rule: State Management - Controls initial presentation stage
    let skipTrialExpiredStage: Bool
    
    /// State for showing full subscription options
    /// Rule: State Management - Local state for nested sheet
    @State private var showAllPlans = false
    
    /// State for controlling sheet expansion (two-stage presentation)
    /// Rule: State Management - Controls transition from compact "trial expired" to full offer
    @State private var isExpanded = false
    
    /// State for navigation to unlimited plan view
    /// Rule: State Management - Controls navigation within sheet to show unlimited plan
    @State private var showUnlimitedPlan = false
    
    /// Standard subscription product
    /// Rule: Subscriptions - Load product to show actual pricing
    @State private var standardProduct: Product?
    
    /// Unlimited subscription product
    /// Rule: Subscriptions - Load unlimited product for promotional view
    @State private var unlimitedProduct: Product?
    
    /// Environment for color scheme detection
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Constants
    
    /// Product ID for Standard subscription
    private let standardProductID = "PremiumStandardSub"
    
    /// Product ID for Unlimited subscription
    private let unlimitedProductID = "unlimited"
    
    /// Blue gradient colors for header
    /// Rule: Visual Design - Balanced gradient with #0b6dd1 to #4a95df (visible but refined)
    private let gradientStart = Color(red: 0x0b/255.0, green: 0x6d/255.0, blue: 0xd1/255.0) // #0b6dd1 (main blue)
    private let gradientEnd = Color(red: 0x4a/255.0, green: 0x95/255.0, blue: 0xdf/255.0)   // #4a95df (balanced lighter shade)
    
    /// Button color (solid, no gradient)
    /// Rule: Visual Design - Button uses main blue color without gradient
    private let buttonColor = Color(red: 0x0b/255.0, green: 0x6d/255.0, blue: 0xd1/255.0) // #0b6dd1
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if isExpanded {
                // STAGE 2: Full offer details with gradient header
                fullOfferView
            } else {
                // STAGE 1: Compact "trial expired" message
                compactTrialExpiredView
            }
        }
        .sheet(isPresented: $showAllPlans) {
            // Rule: Subscriptions - Present full subscription store when user wants to see all options
            SubscriptionStoreSheet(
                isPresented: $showAllPlans,
                customTitle: "Choose your plan"
            )
        }
        .onAppear {
            // Rule: Subscriptions - Load product on appear to get actual pricing
            loadProduct()
            
            // Rule: State Management - Skip to expanded view if requested
            if skipTrialExpiredStage {
                isExpanded = true
            }
        }
        .onInAppPurchaseCompletion { product, result in
            // Rule: Subscriptions - Handle purchase completion
            if case .success(.success(let verificationResult)) = result {
                switch verificationResult {
                case .verified(let transaction):
                    print("[IntroOfferSheet] Purchase successful: \(transaction.productID)")
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    // Dismiss sheet after successful purchase
                    isPresented = false
                case .unverified(_, let error):
                    print("[IntroOfferSheet] Purchase unverified: \(error)")
                }
            }
        }
    }
    
    // MARK: - Stage 1: Compact Trial Expired View
    
    /// Compact view shown initially when trial expires
    /// Rule: Visual Design - Clean, minimal message with clear call-to-action
    private var compactTrialExpiredView: some View {
        ZStack {
            // Background color - adaptive for light/dark mode
            (colorScheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                // Icon: Hourglass to represent expired trial
                // Rule: Visual Design - SF Symbol with gradient for visual appeal
                Image(systemName: "hourglass.bottomhalf.filled")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [gradientStart, gradientEnd],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Message: Clear communication about trial expiration
                // Rule: Visual Design - Typography hierarchy for clarity
                VStack(spacing: 8) {
                    Text("Your free trial has expired")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text("Subscribe to continue capturing meals and recipes")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                Spacer()
                
                // Call-to-action button with dynamic pricing
                // Rule: Subscriptions - Show intro offer price dynamically from StoreKit
                // Rule: Visual Design - Matching button height (50pt) with full offer view
                VStack(spacing: 12) {
                    if let product = standardProduct,
                       let introOffer = product.subscription?.introductoryOffer {
                        // Button with intro offer pricing
                        Button {
                            print("[IntroOfferSheet] Join button tapped - expanding to full offer")
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            expandToFullOffer()
                        } label: {
                            Text("Join starting at \(introOffer.displayPrice)/month")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50) // Reduced from 56 to 50 to match full offer view
                                .background(buttonColor)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    } else if let product = standardProduct {
                        // Fallback: Show regular price if no intro offer
                        Button {
                            print("[IntroOfferSheet] Join button tapped (no intro offer) - expanding to full offer")
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            expandToFullOffer()
                        } label: {
                            Text("Join for \(product.displayPrice)/month")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50) // Reduced from 56 to 50 to match full offer view
                                .background(buttonColor)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Loading state: Disabled button with loading indicator
                        HStack {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                            Text("Loading...")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50) // Reduced from 56 to 50 to match full offer view
                        .background(buttonColor.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(.horizontal, 24) // Rule: Visual Design - Reduced from 32 to 24 for wider button
                .padding(.bottom, 20)
            }
            
            // MARK: - Close Button (Absolute Top-Right)
            // Rule: Visual Design - Close button in ABSOLUTE top-right corner, independent of content
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Spacer()
                    
                    Button {
                        print("[IntroOfferSheet] Close button tapped (compact view)")
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
    }
    
    // MARK: - Stage 2: Full Offer View
    
    /// Full offer view with gradient header and detailed benefits
    /// Rule: Visual Design - Original beautiful design with blue gradient
    /// Rule: State Management - Wrapped in NavigationStack for navigation to unlimited plan
    private var fullOfferView: some View {
        NavigationStack {
            fullOfferContent
                .navigationDestination(isPresented: $showUnlimitedPlan) {
                    unlimitedPlanView
                }
        }
    }
    
    /// Content of full offer view (separated for navigation)
    /// Rule: General Coding - Extracted for cleaner NavigationStack structure
    private var fullOfferContent: some View {
        ZStack {
            // Background color - adaptive for light/dark mode
            (colorScheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Top Section: Blue Gradient Header (50% of sheet)
                ZStack(alignment: .top) {
                    // Gradient background
                    // Rule: Visual Design - Subtle gradient with #0b6dd1 as main, slight #5195db accent
                    LinearGradient(
                        colors: [gradientStart, gradientEnd],
                        startPoint: .leading,      // Left side
                        endPoint: .trailing        // Right side (subtle)
                    )
                    .ignoresSafeArea(edges: .top)
                    
                    // Content
                    VStack(spacing: 12) {
                        Spacer()
                        
                        // Logo and offer text stacked vertically
                        // Rule: Visual Design - Logo displayed above "Three month offer" text
                        VStack(spacing: 8) {
                            Image("logo")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 75) // Slightly larger than text for prominence
                                .shadow(color: Color.black.opacity(0.25), radius: 2, x: 0, y: 2) // Rule: Visual Design - Subtle shadow for depth
                                .padding(.bottom, 8)
                            
                        }
                        .foregroundColor(.white.opacity(0.7))
                        
                        
                        // Large bold white text: Main offer (dynamic from StoreKit)
                        // Rule: Subscriptions - Pull actual intro offer price and currency from App Store Connect
                        // Rule: Visual Design - 3D embossed text effect matching Apple Music style
                        // Rule: Visual Design - Two-line style with "Standard" large and price smaller/gray
                        if let product = standardProduct,
                           let introOffer = product.subscription?.introductoryOffer {
                            VStack(spacing: 4) {
                                Text("Standard")
                                    .font(.system(size: 40, weight: .heavy))
                                    .foregroundColor(.white)
                                    .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 2) // Dark shadow below
                                    .shadow(color: Color.white.opacity(0.3), radius: 1, x: 0, y: -0.5) // Light highlight above
                                    .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 3) // Soft outer glow for depth
                                
                                Text("only \(introOffer.displayPrice)/month")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.75))
                            }
                            .multilineTextAlignment(.center)
                        } else if let product = standardProduct {
                            // Fallback: Show regular price if no intro offer
                            VStack(spacing: 4) {
                                Text("Standard")
                                    .font(.system(size: 40, weight: .heavy))
                                    .foregroundColor(.white)
                                    .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 2)
                                    .shadow(color: Color.white.opacity(0.3), radius: 1, x: 0, y: -0.5)
                                    .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 3)
                                
                                Text("only \(product.displayPrice)/month")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.75))
                            }
                            .multilineTextAlignment(.center)
                        } else {
                            // Loading state: Show placeholder while product loads
                            Text("Get Carbetic")
                                .font(.system(size: 40, weight: .heavy))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 2)
                                .shadow(color: Color.white.opacity(0.3), radius: 1, x: 0, y: -0.5)
                                .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 3)
                        }
                        Text("three month offer.")
                            .font(.body) // Rule: Visual Design - Increased from .subheadline to .body for better visibility
                            .foregroundColor(.white.opacity(0.85)) // Rule: Visual Design - Prominent white with opacity, consistent across light and dark modes
                        Spacer()
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 20)
                }
                .frame(height: UIScreen.main.bounds.height * 0.50) // 50% of screen height (changed from 60%)
                
                // MARK: - Middle Section: Benefits & Pricing
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Gray box containing benefit text, disclaimer, and pricing details
                    // Rule: Visual Design - Grouped information in rounded container
                    // Rule: Subscriptions - Pricing text inside box for better organization
                    VStack(spacing: 12) {
                        // Primary benefit text
                        // Rule: Visual Design - Clear value proposition
                        Text("Includes 10 daily analyses for meals and recipes.")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true) // Allow multiple lines
                        
                        // Disclaimer text
                        // Rule: Visual Design - Secondary information for offer validity
                        Text("Offer valid for new customers.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true) // Allow multiple lines
                        
                        // Pricing text inside gray box
                        // Rule: Subscriptions - Show intro offer price dynamically from StoreKit
                        if let product = standardProduct, 
                           let introOffer = product.subscription?.introductoryOffer {
                            Text(formatIntroductoryOffer(product: product, introOffer: introOffer))
                                .font(.footnote)
                                .foregroundColor(.secondary.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.top, 4) // Small top padding for separation
                        } else if let product = standardProduct {
                            // Fallback: Show regular price if no intro offer
                            Text("Subscribe for \(product.displayPrice)/Month")
                                .font(.footnote)
                                .foregroundColor(.secondary.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.top, 4)
                        } else {
                            // Loading state
                            ProgressView()
                                .progressViewStyle(.circular)
                                .padding(.top, 4)
                        }
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
                        .frame(maxHeight: 28)
                    
                    // MARK: - Bottom Section: Button
                    // "Accept Now" button - separate from gray box with increased spacing
                    // Rule: Visual Design - Solid color button as separate element
                    Button {
                        print("[IntroOfferSheet] Accept Now tapped")
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        acceptOffer()
                    } label: {
                        Text("Accept Now")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(buttonColor)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(standardProduct == nil)
                    .padding(.horizontal, 24)
                    
                    // MARK: - "Get unlimited instead" Link (Below Gray Box)
                    // Rule: Visual Design - Positioned below Accept Now button with increased spacing
                    // Rule: State Management - Triggers navigation to unlimited plan view
                    Button {
                        print("[IntroOfferSheet] Get unlimited instead tapped - navigating to unlimited plan")
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showUnlimitedPlan = true
                    } label: {
                        Text("Get Unlimited instead")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(colorScheme == .dark ? .white : .blue)
                    }
                    .padding(.top, 18) // Increased spacing from Accept Now button
                    .padding(.bottom, 40) // Extra bottom padding extending into safe area
                    .padding(.horizontal, 24)
                    .background(colorScheme == .dark ? Color.black : Color.white) // Extend background color
                }
                .ignoresSafeArea(edges: .bottom) // Rule: Visual Design - Ignore bottom safe area for "Get unlimited instead"
            }
            
            // MARK: - Close Button (Absolute Top-Right)
            // Rule: Visual Design - Close button in ABSOLUTE top-right corner, independent of content
            // Rule: State Management - Only show on intro offer view, hidden when navigating
            if !showUnlimitedPlan {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Spacer()
                        
                        Button {
                            print("[IntroOfferSheet] Close button tapped")
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            isPresented = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.black.opacity(0.3))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.top, 16) // Reduced padding to move closer to top
                    .padding(.trailing, 16) // Reduced padding to move closer to right edge
                    
                    Spacer()
                }
                .zIndex(999) // Ensure close button is always on top, independent of content layout
            }
        }
    }
    
    // MARK: - Unlimited Plan View
    
    /// Unlimited plan promotional view
    /// Rule: Visual Design - Similar to Standard plan but with adaptive background (black in dark mode, gradient in light mode)
    /// Rule: Subscriptions - Pull actual intro offer pricing from StoreKit
    private var unlimitedPlanView: some View {
        ZStack {
            // Adaptive background: Black in dark mode, blue gradient in light mode
            // Rule: Visual Design - Consistent with dark mode aesthetics while maintaining light mode premium feel
            Group {
                if colorScheme == .dark {
                    Color.black
                        .ignoresSafeArea()
                } else {
                    LinearGradient(
                        colors: [
                            Color(red: 0xD5/255.0, green: 0xE8/255.0, blue: 0xF0/255.0), // Top: More noticeable light blue
                            Color(red: 0xF0/255.0, green: 0xF6/255.0, blue: 0xFA/255.0)  // Bottom: Soft blue-white
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                }
            }
            
            VStack(spacing: 0) {
                // MARK: - Top Section: Header (50% of sheet)
                ZStack(alignment: .top) {
                    // Content
                    VStack(spacing: 12) {
                        Spacer()
                        
                        // Logo
                        VStack(spacing: 8) {
                            Image("logo")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 75)
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
                    
                    // Gray box containing benefit text, disclaimer, and pricing details
                    // Rule: Visual Design - Grouped information in rounded container
                    // Rule: Subscriptions - Pricing text inside box for better organization
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
                        
                        // Pricing text inside gray box
                        // Rule: Subscriptions - Show intro offer price dynamically from StoreKit
                        if let product = unlimitedProduct,
                           let introOffer = product.subscription?.introductoryOffer {
                            Text(formatIntroductoryOffer(product: product, introOffer: introOffer))
                                .font(.footnote)
                                .foregroundColor(.secondary.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.top, 4) // Small top padding for separation
                        } else if let product = unlimitedProduct {
                            // Fallback
                            Text("Subscribe for \(product.displayPrice)/Month")
                                .font(.footnote)
                                .foregroundColor(.secondary.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.top, 4)
                        } else {
                            // Loading state
                            ProgressView()
                                .progressViewStyle(.circular)
                                .padding(.top, 4)
                        }
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
                        .frame(maxHeight: 28)
                    
                    // MARK: - Bottom Section: Button
                    // "Accept Now" button - separate from gray box with increased spacing
                    // Rule: Visual Design - Solid color button as separate element
                    Button {
                        print("[IntroOfferSheet] Accept Unlimited offer tapped")
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        acceptUnlimitedOffer()
                    } label: {
                        Text("Accept Now")
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
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Helper Methods
    
    /// Expand sheet from compact "trial expired" view to full offer details
    /// Rule: Visual Design - Smooth animation with spring curve for natural feel
    /// Rule: State Management - Triggers transition between two-stage presentation
    private func expandToFullOffer() {
        print("[IntroOfferSheet] Expanding sheet from compact to full offer view")
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isExpanded = true
        }
    }
    
    /// Load the Standard and Unlimited subscription products from StoreKit
    /// Rule: Subscriptions - Fetch products to show actual pricing
    private func loadProduct() {
        Task {
            do {
                let products = try await Product.products(for: [standardProductID, unlimitedProductID])
                
                await MainActor.run {
                    // Find and assign Standard product
                    if let standard = products.first(where: { $0.id == standardProductID }) {
                        standardProduct = standard
                        print("[IntroOfferSheet] Loaded Standard product: \(standard.displayName) - \(standard.displayPrice)")
                        
                        if let intro = standard.subscription?.introductoryOffer {
                            print("[IntroOfferSheet] Standard introductory offer: \(intro.displayPrice)")
                        }
                    } else {
                        print("[IntroOfferSheet] ⚠️ Standard product not found")
                    }
                    
                    // Find and assign Unlimited product
                    if let unlimited = products.first(where: { $0.id == unlimitedProductID }) {
                        unlimitedProduct = unlimited
                        print("[IntroOfferSheet] Loaded Unlimited product: \(unlimited.displayName) - \(unlimited.displayPrice)")
                        
                        if let intro = unlimited.subscription?.introductoryOffer {
                            print("[IntroOfferSheet] Unlimited introductory offer: \(intro.displayPrice)")
                        }
                    } else {
                        print("[IntroOfferSheet] ⚠️ Unlimited product not found")
                    }
                }
            } catch {
                print("[IntroOfferSheet] ❌ Failed to load products: \(error)")
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
    
    /// Format the duration from a subscription period
    /// Rule: Subscriptions - Extract duration dynamically from StoreKit for disclaimer text
    /// Returns formatted string like "3 Months", "1 Year", etc. with capitalized unit
    private func formatDuration(from period: Product.SubscriptionPeriod) -> String {
        let periodValue = period.value
        
        // Format based on period unit with capitalization for disclaimer text
        switch period.unit {
        case .month:
            return periodValue == 1 ? "1 Month" : "\(periodValue) Months"
        case .year:
            return periodValue == 1 ? "1 Year" : "\(periodValue) Years"
        case .week:
            return periodValue == 1 ? "1 Week" : "\(periodValue) Weeks"
        case .day:
            return periodValue == 1 ? "1 Day" : "\(periodValue) Days"
        @unknown default:
            return "\(periodValue) Periods"
        }
    }
    
    /// Initiate purchase of Standard subscription
    /// Rule: Subscriptions - Use StoreKit 2 purchase flow
    private func acceptOffer() {
        guard let product = standardProduct else {
            print("[IntroOfferSheet] ⚠️ Cannot purchase - product not loaded")
            return
        }
        
        Task {
            do {
                print("[IntroOfferSheet] Starting purchase for: \(product.displayName)")
                let result = try await product.purchase()
                
                switch result {
                case .success(let verification):
                    let transaction = try checkVerified(verification)
                    print("[IntroOfferSheet] ✅ Purchase successful: \(transaction.productID)")
                    await transaction.finish()
                    
                    // Success handled by onInAppPurchaseCompletion modifier
                    
                case .userCancelled:
                    print("[IntroOfferSheet] User cancelled purchase")
                    
                case .pending:
                    print("[IntroOfferSheet] Purchase pending (Ask to Buy)")
                    
                @unknown default:
                    print("[IntroOfferSheet] Unknown purchase result")
                }
            } catch {
                print("[IntroOfferSheet] ❌ Purchase failed: \(error)")
            }
        }
    }
    
    /// Initiate purchase of Unlimited subscription
    /// Rule: Subscriptions - Use StoreKit 2 purchase flow
    private func acceptUnlimitedOffer() {
        guard let product = unlimitedProduct else {
            print("[IntroOfferSheet] ⚠️ Cannot purchase - unlimited product not loaded")
            return
        }
        
        Task {
            do {
                print("[IntroOfferSheet] Starting purchase for: \(product.displayName)")
                let result = try await product.purchase()
                
                switch result {
                case .success(let verification):
                    let transaction = try checkVerified(verification)
                    print("[IntroOfferSheet] ✅ Purchase successful: \(transaction.productID)")
                    await transaction.finish()
                    
                    // Success handled by onInAppPurchaseCompletion modifier
                    
                case .userCancelled:
                    print("[IntroOfferSheet] User cancelled purchase")
                    
                case .pending:
                    print("[IntroOfferSheet] Purchase pending (Ask to Buy)")
                    
                @unknown default:
                    print("[IntroOfferSheet] Unknown purchase result")
                }
            } catch {
                print("[IntroOfferSheet] ❌ Purchase failed: \(error)")
            }
        }
    }
    
    /// Verify a transaction result
    /// Rule: Security - Always verify transactions to prevent fraud
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            print("[IntroOfferSheet] Transaction verification failed")
            throw NSError(domain: "IntroOfferSheet", code: 1, userInfo: [NSLocalizedDescriptionKey: "Transaction verification failed"])
        case .verified(let safe):
            return safe
        }
    }
}

// MARK: - Preview

#Preview("Intro Offer Sheet - Trial Expired") {
    IntroOfferSheet(isPresented: .constant(true), skipTrialExpiredStage: false)
}

#Preview("Intro Offer Sheet - Direct to Offer") {
    IntroOfferSheet(isPresented: .constant(true), skipTrialExpiredStage: true)
}

