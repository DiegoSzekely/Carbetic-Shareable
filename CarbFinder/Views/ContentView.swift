//
//  ContentView.swift
//  CarbFinder
//
//  Created by Diego Szekely on 14.10.25.
//

import SwiftUI
import UIKit
import WebKit // Import WebKit for in-app web viewer
import StoreKit // Import StoreKit

struct ContentView: View {
    @State private var showCaptureFlow = false
    @State private var showRecipeScanFlow = false // NEW: Recipe scan flow state
    @State private var showRecipeLinkView = false // NEW: Recipe link entry flow state
    @State private var currentCardID: AnyHashable? = nil
    @State private var showHistoryView = false // NEW: Navigate to HistoryView
    // Rule: State Management - Use @EnvironmentObject to access app-wide history store
    // This ensures we use the SAME instance created in CarbFinderApp, not a duplicate
    @EnvironmentObject var historyStore: ScanHistoryStore
    // Rule: State Management - Access installation manager for trial period and loading state
    @EnvironmentObject var installationManager: UserInstallationManager
    // Rule: State Management - Access subscription manager for subscription status
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    // Rule: State Management - Access usage manager for daily capture tracking
    @EnvironmentObject var usageManager: CaptureUsageManager
    // Rule: State Management - Access network monitor for connectivity status
    @EnvironmentObject var networkMonitor: NetworkMonitor
    // Rule: State Management - Access promo box manager for dynamic promotional content
    @EnvironmentObject var promoBoxManager: PromoBoxManager
    private let storage = CaptureStorage()
    private let recipeStorage = RecipeCaptureStorage() // NEW: Recipe storage
    // Rule: State Management - Use @State for local view-managed state
    @State private var showUpgradeSheet = false
    @State private var showPlanView = false // NEW: State for presenting PlanView sheet
    @State private var showIntroOfferSheet = false // NEW: State for presenting IntroOfferSheet when trial ends (replaces TrialExpiredSheet)
    @Environment(\.colorScheme) private var colorScheme 

    // State for presenting past result details
    @State private var showingHistoryResult = false
    @State private var showRecipeHistoryResult = false // NEW: Present recipe sheet deterministically
    @State private var showMealHistoryResult = false   // NEW: Present meal sheet deterministically
    @State private var selectedHistoryResultJSON: String? = nil
    @State private var selectedHistoryImage: UIImage? = nil // NEW: Store selected history entry's image
    @State private var selectedIsLoading: Bool = false
    @State private var selectedHistoryRecipeURL: URL? = nil // NEW: Store link for link-based recipes
    @State private var selectedIsRecipeScan: Bool = false // NEW: Stable flag to choose correct sheet the first time
    @State private var showLimitReachedAlert = false // NEW: Alert for when daily limit is reached
    @State private var showNoInternetOverlay = false // NEW: Overlay when network is unavailable
    @State private var showExplanatoryText = true // Rule: State Management - Track if explanatory text box is visible
    @State private var showPromoBox = true // Rule: State Management - Track if promotional box is visible
    @State private var showPromoWebView = false // Rule: State Management - Track if promotional web view should be shown
    @State private var showShareSheet = false // Rule: State Management - Track if share sheet should be shown
    
    // Rule: State Management - Track app initialization state for returning users
    // First-time users see WelcomeView, returning users see InitializationView
    @StateObject private var initializationManager = AppInitializationManager.shared
    
    /// Helper to determine if JSON is from a recipe scan or meal scan
    private func isRecipeScan(json: String?) -> Bool {
        guard let json = json else { return false }
        // Recipe scans have "portionsCount", meal scans have "components"
        return json.contains("portionsCount") || json.contains("portions") || json.contains("recipeDescription")
    }
    
    /// Computes the status text based on current subscription tier and usage
    /// Rule: Subscriptions - Dynamic text showing "Below limit", "Limit reached", or "No limit"
    private var statusText: String {
        // Unlimited users always see "No limit"
        if subscriptionManager.currentTier == .unlimited {
            return "No limit"
        }
        
        // Free trial and Standard users see usage-based status
        let hasReached = usageManager.hasReachedLimit(tier: subscriptionManager.currentTier)
        return hasReached ? "Limit reached" : "Below limit"
    }
    
    /// Extracts recipe description from AI result JSON
    /// Rule: General Coding - Helper function for parsing recipe description
    private func getRecipeDescription(from json: String?) -> String? {
        guard let json = json,
              let data = json.data(using: .utf8) else { return nil }
        
        do {
            if let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let description = decoded["recipeDescription"] as? String {
                return description
            }
        } catch {
            print("[ContentView] Failed to parse recipe description: \(error)")
        }
        return nil
    }
    
    /// Extracts meal summary from AI result JSON
    /// Rule: General Coding - Helper function for parsing meal summary
    private func getMealSummary(from json: String?) -> String? {
        guard let json = json,
              let data = json.data(using: .utf8) else { return nil }
        
        do {
            if let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let summary = decoded["mealSummary"] as? String {
                return summary
            }
        } catch {
            print("[ContentView] Failed to parse meal summary: \(error)")
        }
        return nil
    }

    /// Dismisses the capture flow and clears any captured images.
    private func cancelCaptureFlow() {
        print("[Flow] Capture flow cancelled by user.") // Rule: General Coding - Add debug logs
        storage.clear()
        showCaptureFlow = false
    }
    
    /// Dismisses the recipe scan flow and clears any captured image.
    private func cancelRecipeScanFlow() {
        print("[Flow] Recipe scan flow cancelled by user.") // Rule: General Coding - Add debug logs
        recipeStorage.clear()
        showRecipeScanFlow = false
    }
    
    /// Checks if user can start a new capture based on trial status and daily limit
    /// Rule: Subscriptions - NO FREE PLAN. Trial expired = must subscribe.
    /// Returns true if capture allowed, false if blocked (shows TrialExpiredSheet or alert)
    private func checkCaptureLimit() -> Bool {
        // FIRST: Check network connectivity
        // Rule: General Coding - Block network-dependent actions when offline
        if !networkMonitor.isConnected {
            print("[AccessControl] ❌ No internet connection -> showing overlay")
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                showNoInternetOverlay = true
            }
            return false
        }
        
        // CRITICAL: Check if user has active subscription or trial
        // Rule: Subscriptions - "THERE IS NO FREE PLAN" - trial expired users CANNOT capture
        let hasPaidSubscription = subscriptionManager.currentTier == .premium || subscriptionManager.currentTier == .unlimited
        let hasActiveTrial = installationManager.isWithinTrialPeriod()
        
        // If no subscription AND trial expired -> block completely, open IntroOfferSheet
        if !hasPaidSubscription && !hasActiveTrial {
            print("[AccessControl] ❌ Trial expired, no subscription -> opening IntroOfferSheet")
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showIntroOfferSheet = true // Open beautiful intro offer sheet with Standard plan highlight
            return false
        }
        
        // If has subscription or active trial -> check daily limit
        let hasReached = usageManager.hasReachedLimit(tier: subscriptionManager.currentTier)
        
        if hasReached {
            print("[AccessControl] Daily limit reached (\(usageManager.capturesUsedToday)/\(subscriptionManager.currentTier.dailyCaptureLimit)), showing alert")
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showLimitReachedAlert = true // Rule: Subscriptions - Show alert as per requirements
            return false
        }
        
        print("[AccessControl] ✅ Capture allowed - Tier: \(subscriptionManager.currentTier.displayName), Trial active: \(hasActiveTrial), Usage: \(usageManager.capturesUsedToday)/\(subscriptionManager.currentTier.dailyCaptureLimit)")
        return true
    }

    // Computed property to determine the ideal height for the history row
    // Now, the card height encompasses both the image and its overlaid text.
    // Rule: Visual Design - Reduced by 20% from 0.30 to 0.24
    private var historyRowIdealHeight: CGFloat {
        return UIScreen.main.bounds.height * 0.24 // Reduced height factor (20% smaller than 0.30)
    }
    
    var body: some View {
        // Rule: State Management - Show initialization screen for returning users
        // First-time users see WelcomeView instead (managed in CarbFinderApp)
        Group {
            if initializationManager.isReady {
                homeView
            } else {
                InitializationView()
            }
        }
        .onAppear {
            // Rule: State Management - Start initialization tracking when ContentView appears
            // This only happens for returning users (first-time users see WelcomeView)
            initializationManager.startInitialization(installationManager: installationManager)
        }
    }
    
    private var homeView: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // Rule: Visual Design - Light blue background (#E7F0F2) when first-time user (no history), white otherwise
                    if historyStore.entries.isEmpty {
                        Color(red: 0xE7/255.0, green: 0xF0/255.0, blue: 0xF2/255.0)
                            .ignoresSafeArea(.all)
                    } else {
                        Color.white
                            .ignoresSafeArea(.all)
                    }
                    
                    // Rule: Visual Design - Background color #E7F0F2 above and below the image (only when history exists)
                    if !historyStore.entries.isEmpty {
                        VStack(spacing: 0) {
                            // Top area with background color #E7F0F2
                            Color(red: 0xE7/255.0, green: 0xF0/255.0, blue: 0xF2/255.0)
                                .frame(height: 122) // Rule: Visual Design - Reduced by 15% from 144 (144 × 0.85 ≈ 122)
                            
                            // Header image - natural aspect ratio, width fills screen
                            // Rule: Visual Design - Allow image to display at its natural height based on aspect ratio
                            Image("home-header")
                                .resizable()
                                .scaledToFit() // Changed from scaledToFill to scaledToFit for natural aspect ratio
                                .frame(width: UIScreen.main.bounds.width) // Width fills screen, height determined by aspect ratio
                            
                            // MARK: - Subscription/Promotional Box Overlay Area
                            // Rule: Visual Design - 20% screen height colored area below image with boxes positioned relative to this
                            // Rule: State Management - Show subscription box for free users with history, promo box for subscribed users
                            Color(red: 0xE7/255.0, green: 0xF0/255.0, blue: 0xF2/255.0)
                                .frame(height: UIScreen.main.bounds.height * 0.14) // 14% of screen height
                                .overlay(alignment: .top) {
                                    // Overlay subscription/promotional box at top of this colored area
                                    VStack(spacing: 0) {
                                        // MARK: - Subscription Box (only for users with history but no subscription)
                                        if showExplanatoryText && subscriptionManager.currentTier == .free {
                                        // Subscription box for users with history but no subscription - tappable, not dismissible
                                        // Rule: Visual Design - Always render in light mode appearance even in dark mode
                                        Button {
                                            print("[UI] Subscription box tapped - opening upgrade sheet") // Rule: General Coding - Add debug logs
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            showUpgradeSheet = true // Open StoreKit subscription sheet
                                        } label: {
                                            HStack(spacing: 12) {
                                                // App logo
                                                Image("logo")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 40, height: 40)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                                
                                                // Vertical divider
                                                Rectangle()
                                                    .fill(Color.black.opacity(0.2))
                                                    .frame(width: 1, height: 40)
                                                
                                                // Text content
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text("Subscribe to Carbetic")
                                                        .font(.subheadline)
                                                        .fontWeight(.bold)
                                                        .foregroundStyle(Color.black)
                                                    
                                                    Text("Get 10/day or unlimited scans")
                                                        .font(.caption)
                                                        .foregroundStyle(Color(white: 0.4))
                                                }
                                                
                                                Spacer()
                                                
                                                // Rule: Visual Design - Chevron to indicate clickable box
                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundStyle(Color(white: 0.4))
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                            .frame(width: UIScreen.main.bounds.width * 0.9)
                                            .background(
                                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                    .fill(Color.white)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                    .stroke(Color.black.opacity(0.15), lineWidth: 0.5)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                    }
                                    
                                    // MARK: - Promotional Box (only for subscribed users with history)
                                    if (subscriptionManager.currentTier == .premium || subscriptionManager.currentTier == .unlimited)
                                        && promoBoxManager.config.isEnabled {
                                        // Promotional box with dynamic content from Firebase - not dismissible
                                        // Rule: Visual Design - Match subscription box layout structure exactly
                                        if promoBoxManager.config.enableShare && promoBoxManager.config.shareText != nil {
                                                // Tappable box with share functionality
                                                Button {
                                                    print("[UI] Promotional box tapped - opening share sheet") // Rule: General Coding - Add debug logs
                                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                                    showShareSheet = true
                                                } label: {
                                                    HStack(spacing: 12) {
                                                        // Dynamic icon: App logo or SF Symbol
                                                        switch promoBoxManager.config.iconType {
                                                        case .appLogo:
                                                            Image("logo")
                                                                .resizable()
                                                                .scaledToFit()
                                                                .frame(width: 40, height: 40)
                                                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                                        case .sfSymbol(let symbolName):
                                                            Image(systemName: symbolName)
                                                                .font(.system(size: 32, weight: .regular))
                                                                .foregroundStyle(Color(white: 0.4))
                                                                .frame(width: 40, height: 40)
                                                        }
                                                        
                                                        // Vertical divider
                                                        Rectangle()
                                                            .fill(Color.black.opacity(0.2))
                                                            .frame(width: 1, height: 40)
                                                        
                                                        // Dynamic text content
                                                        VStack(alignment: .leading, spacing: 2) {
                                                            Text(promoBoxManager.config.title)
                                                                .font(.subheadline)
                                                                .fontWeight(.bold)
                                                                .foregroundStyle(Color.black)
                                                            
                                                            Text(promoBoxManager.config.subtitle)
                                                                .font(.caption)
                                                                .foregroundStyle(Color(white: 0.4))
                                                        }
                                                        
                                                        Spacer()
                                                        
                                                        // Rule: Visual Design - Chevron to indicate clickable box
                                                        Image(systemName: "chevron.right")
                                                            .font(.system(size: 14, weight: .semibold))
                                                            .foregroundStyle(Color(white: 0.4))
                                                    }
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 12)
                                                    .frame(width: UIScreen.main.bounds.width * 0.9)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                            .fill(Color.white)
                                                    )
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                            .stroke(Color.black.opacity(0.15), lineWidth: 0.5)
                                                    )
                                                }
                                                .buttonStyle(.plain)
                                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                            } else if let linkURL = promoBoxManager.config.linkURL, !linkURL.isEmpty {
                                                // Tappable box with link
                                                Button {
                                                    print("[UI] Promotional box tapped - opening web viewer") // Rule: General Coding - Add debug logs
                                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                                    showPromoWebView = true
                                                } label: {
                                                    HStack(spacing: 12) {
                                                        // Dynamic icon: App logo or SF Symbol
                                                        switch promoBoxManager.config.iconType {
                                                        case .appLogo:
                                                            Image("logo")
                                                                .resizable()
                                                                .scaledToFit()
                                                                .frame(width: 40, height: 40)
                                                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                                        case .sfSymbol(let symbolName):
                                                            Image(systemName: symbolName)
                                                                .font(.system(size: 32, weight: .regular))
                                                                .foregroundStyle(Color(white: 0.4))
                                                                .frame(width: 40, height: 40)
                                                        }
                                                        
                                                        // Vertical divider
                                                        Rectangle()
                                                            .fill(Color.black.opacity(0.2))
                                                            .frame(width: 1, height: 40)
                                                        
                                                        // Dynamic text content
                                                        VStack(alignment: .leading, spacing: 2) {
                                                            Text(promoBoxManager.config.title)
                                                                .font(.subheadline)
                                                                .fontWeight(.bold)
                                                                .foregroundStyle(Color.black)
                                                            
                                                            Text(promoBoxManager.config.subtitle)
                                                                .font(.caption)
                                                                .foregroundStyle(Color(white: 0.4))
                                                        }
                                                        
                                                        Spacer()
                                                        
                                                        // Rule: Visual Design - Chevron to indicate clickable box
                                                        Image(systemName: "chevron.right")
                                                            .font(.system(size: 14, weight: .semibold))
                                                            .foregroundStyle(Color(white: 0.4))
                                                    }
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 12)
                                                    .frame(width: UIScreen.main.bounds.width * 0.9)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                            .fill(Color.white)
                                                    )
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                            .stroke(Color.black.opacity(0.15), lineWidth: 0.5)
                                                    )
                                                }
                                                .buttonStyle(.plain)
                                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                            } else {
                                                // Non-tappable box (no share or link configured)
                                                HStack(spacing: 12) {
                                                    // Dynamic icon: App logo or SF Symbol
                                                    switch promoBoxManager.config.iconType {
                                                    case .appLogo:
                                                        Image("logo")
                                                            .resizable()
                                                            .scaledToFit()
                                                            .frame(width: 40, height: 40)
                                                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                                    case .sfSymbol(let symbolName):
                                                        Image(systemName: symbolName)
                                                            .font(.system(size: 32, weight: .regular))
                                                            .foregroundStyle(Color(white: 0.4))
                                                            .frame(width: 40, height: 40)
                                                    }
                                                    
                                                    // Vertical divider
                                                    Rectangle()
                                                        .fill(Color.black.opacity(0.2))
                                                        .frame(width: 1, height: 40)
                                                    
                                                    // Dynamic text content
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(promoBoxManager.config.title)
                                                            .font(.subheadline)
                                                            .fontWeight(.bold)
                                                            .foregroundStyle(Color.black)
                                                        
                                                        Text(promoBoxManager.config.subtitle)
                                                            .font(.caption)
                                                            .foregroundStyle(Color(white: 0.4))
                                                    }
                                                    
                                                    Spacer()
                                                }
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 12)
                                                .frame(width: UIScreen.main.bounds.width * 0.9)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                        .fill(Color.white)
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                        .stroke(Color.black.opacity(0.15), lineWidth: 0.5)
                                                )
                                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                            }
                                    }
                                }
                                .padding(.top, 30) // Rule: Visual Design -  offset from top of colored area
                            }
                        
                        // White background continues below (handled by white background layer)
                        Spacer()
                    }
                    .ignoresSafeArea(.all, edges: .top)
                    }
                    
                VStack { // Outermost VStack for overall layout
                let cardWidth = UIScreen.main.bounds.width * 0.38
                let cardHeight = UIScreen.main.bounds.height * 0.24 // Reduced card height by 20% (was 0.30)
                let cardSpacing = UIScreen.main.bounds.width * 0.05
                let peekAmount = UIScreen.main.bounds.width * 0.015 // Rule: Visual Design - Very subtle peek of 1.5% screen width

                    
                // Rule: Visual Design - Spacer pushes everything to bottom
                Spacer()

                // MARK: - History Section or First-Time User Box
                // Rule: Visual Design - Different layout based on whether user has history entries
                if historyStore.entries.isEmpty {
                    // FIRST-TIME USER: Show image and instructional box with equal spacing
                    // Rule: Visual Design - Image positioned exactly between title and box with equal spacing
                    // Rule: Visual Design - Box positioned close to capture buttons at bottom
                    VStack(spacing: 0) {
                        // Equal spacing above image
                        Spacer()
                        
                        // Header image - full width
                        Image("home-header")
                            .resizable()
                            .scaledToFit()
                            .frame(width: UIScreen.main.bounds.width)
                        
                        // Equal spacing below image
                        Spacer()
                        
                        // First-time user instructional box
                        if showExplanatoryText {
                            // Show the full instructional box
                            ZStack(alignment: .topTrailing) {
                                VStack(alignment: .leading, spacing: 0) { // Rule: Visual Design - Manual spacing control for different section gaps
                                    // Top row: Logo + Divider + Info Icon
                                    // Rule: Visual Design - Clean horizontal layout with consistent spacing
                                    HStack(spacing: 10) {
                                    // App logo
                                    Image("logo")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 32, height: 32)
                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    
                                    // Vertical divider
                                    Rectangle()
                                        .fill(Color.primary.opacity(0.25))
                                        .frame(width: 1, height: 32)
                                    
                                    // Info icon
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 31, weight: .regular))
                                        .foregroundStyle(Color(white: 0.4))
                                }
                                
                                Spacer()
                                    .frame(height: 15) // Rule: Visual Design - 15pt spacing between icon and title
                                
                                // Title below the icon row
                                // Rule: Visual Design - Refined typography for Apple-style hierarchy
                                // Rule: Visual Design - Always render in black (light mode appearance) even in dark mode
                                Text("How to use Carbetic")
                                    .font(.system(size: 23, weight: .semibold, design: .default))
                                    .foregroundStyle(Color.black)
                                
                                Spacer()
                                    .frame(height: 35) // Rule: Visual Design - 35pt spacing between title and instructions
                                
                                // Two-step instructions with subtle vertical progress bar
                                // Rule: Visual Design - Small, subtle progress bar that doesn't distract
                                HStack(alignment: .top, spacing: 12) {
                                    // Subtle vertical progress bar with SF symbols
                                    VStack(spacing: 0) {
                                        // Step 1 circle with camera icon
                                        ZStack {
                                            Circle()
                                                .fill(Color.blue.opacity(0.15))
                                                .frame(width: 24, height: 24)
                                            
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundStyle(.blue)
                                        }
                                        
                                        // Connecting line
                                        // Rule: Visual Design - Tripled height from 20 to 60 to match increased text spacing
                                        Rectangle()
                                            .fill(Color.blue.opacity(0.3))
                                            .frame(width: 2, height: 40)
                                        
                                        // Step 2 circle with arrow icon
                                        ZStack {
                                            Circle()
                                                .fill(Color.blue.opacity(0.15))
                                                .frame(width: 24, height: 24)
                                            
                                            Image(systemName: "arrow.forward")
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                    
                                    // Instructions text
                                    // Rule: Visual Design - Tripled spacing from 20 to 60 for clearer visual separation between steps
                                    // Rule: Visual Design - Always render in light mode appearance even in dark mode
                                    VStack(alignment: .leading, spacing: 40) {
                                        Text("Capture a meal or recipe using your camera")
                                            .font(.system(size: 17))
                                            .foregroundStyle(Color(white: 0.4))
                                            .fixedSize(horizontal: false, vertical: true)
                                            .frame(height: 24, alignment: .center)
                                        
                                        Text("Carbetic outputs the net carbs in your meal")
                                            .font(.system(size: 17))
                                            .foregroundStyle(Color(white: 0.4))
                                            .fixedSize(horizontal: false, vertical: true)
                                            .frame(height: 24, alignment: .center)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.top, 28) // Rule: Visual Design - More top padding for breathing room
                            .padding(.bottom, 28) // Rule: Visual Design - More bottom padding for breathing room
                            .padding(.trailing, 32) // Extra padding on right to avoid X button overlap
                            
                            // X button in top-right corner
                            // Rule: Visual Design - X button positioned in top-right corner
                            // Rule: Visual Design - Always render in light mode appearance even in dark mode
                            Button {
                                print("[UI] First-time user box dismissed") // Rule: General Coding - Add debug logs
                                UIImpactFeedbackGenerator(style: .light).impactOccurred() // Rule: General Coding - Haptic feedback for better UX
                                withAnimation(.easeOut(duration: 0.25)) {
                                    showExplanatoryText = false
                                }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color(white: 0.4))
                                    .frame(width: 28, height: 28)
                                    .contentShape(Rectangle()) // Larger tap target
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 14) // Position from top edge
                            .padding(.trailing, 14) // Position from right edge
                            .zIndex(1) // Rule: Visual Design - Ensure button appears above text content
                        }
                        .frame(width: UIScreen.main.bounds.width * 0.9) // Rule: Visual Design - Dynamic height based on content
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white) // Rule: Visual Design - White background for first-time user box
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.primary.opacity(0.15), lineWidth: 0.5) // Rule: Visual Design - Subtle border matching subscription box
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    } else {
                        // Show "Show instructions again." text when box is dismissed
                        // Rule: State Management - Toggle showExplanatoryText to bring back the box
                        // Rule: Visual Design - Always render in black (light mode appearance) even in dark mode
                        Button {
                            print("[UI] Show instructions again tapped") // Rule: General Coding - Add debug logs
                            UIImpactFeedbackGenerator(style: .light).impactOccurred() // Rule: General Coding - Haptic feedback for better UX
                            withAnimation(.easeOut(duration: 0.25)) {
                                showExplanatoryText = true
                            }
                        } label: {
                            Text("Show instructions again")
                                .font(.callout)
                                .foregroundStyle(Color.black)
                        }
                        .buttonStyle(.plain)
                        .frame(width: UIScreen.main.bounds.width * 0.9)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                    }
                } else {
                    // RETURNING USER: Show History section with title and scrollable cards
                    VStack(spacing: 12) { // Rule: Visual Design - Increased spacing from 1 to 12 for better visual separation
                        // MARK: - History Title
                        // Rule: Visual Design - Always render in black/light mode appearance even in dark mode
                        HStack(alignment: .center, spacing: 8) {
                            Button {
                                print("[ContentView] History header tapped") // Rule: General Coding - Add debug logs
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                showHistoryView = true
                            } label: {
                                HStack(spacing: 6) {
                                    Text("History")
                                        .font(.title2) // Rule: Visual Design - Increased from .title3 to .title2
                                        .fontWeight(.bold)
                                        .foregroundColor(Color.black)
                                    // Rule: General Coding - Only show chevron when there are history entries
                                    if !historyStore.entries.isEmpty {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 18, weight: .semibold)) // Rule: Visual Design - Increased from 16 to 18
                                            .foregroundStyle(Color(white: 0.4))
                                            .offset(y: 1) // Slight baseline alignment for better visual balance
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Open history")
                            .accessibilityIdentifier("history-header-button")
                            
                            Spacer() // Rule: Visual Design - Push button to left edge
                        }
                        .frame(maxWidth: .infinity, alignment: .leading) // Rule: Visual Design - Force left alignment
                        .padding(.horizontal, cardSpacing) // Align with cards
                        
                        // Scrollable cards row for real entries only (max 10)
                        // Tap a card to open full results in a sheet that mirrors ResultView
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: cardSpacing - peekAmount) { // Rule: Visual Design - Reduce spacing to compensate for peek
                                ForEach(Array(historyStore.entries.prefix(10))) { entry in
                                    Button {
                                        // Rule: General Coding - Add haptic feedback for better UX
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        
                                        // On tap: present ResultView sheet for this history item
                                        selectedHistoryResultJSON = entry.aiResultJSON
                                        // Rule: State Management - For link-based recipes, don't pass image (pass nil)
                                        // This ensures RecipeResultView shows the correct navbar button (link vs image)
                                        if let s = entry.recipeURLString, let u = URL(string: s) { 
                                            selectedHistoryRecipeURL = u
                                            selectedHistoryImage = nil // Link-based recipe: no image
                                        } else { 
                                            selectedHistoryRecipeURL = nil
                                            selectedHistoryImage = historyStore.image(for: entry) // Camera-scanned: use image
                                        }
                                        selectedIsRecipeScan = isRecipeScan(json: entry.aiResultJSON)
                                        selectedIsLoading = false
                                        // Present the correct sheet deterministically
                                        if selectedIsRecipeScan {
                                            showMealHistoryResult = false
                                            showRecipeHistoryResult = true
                                        } else {
                                            showRecipeHistoryResult = false
                                            showMealHistoryResult = true
                                        }
                                        print("[UI] History card tapped. hasAIJSON=\(entry.aiResultJSON != nil), isLink=\(entry.recipeURLString != nil)")
                                    } label: {
                                        ZStack(alignment: .bottom) {
                                            // Base image or placeholder (fallback gray if image missing)
                                            if let uiImage = historyStore.image(for: entry) {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: cardWidth, height: cardHeight)
                                                    .clipped()
                                            } else {
                                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                                    .fill(Color.gray.opacity(0.3))
                                                    .frame(width: cardWidth, height: cardHeight)
                                                    .overlay(
                                                        Image(systemName: "photo")
                                                            .font(.title)
                                                            .foregroundStyle(Color(white: 0.4))
                                                    )
                                            }
                                            
                                            // Recipe icon badge (top-right corner) - only for recipe scans
                                            // Rule: Visual Design - Always render in light mode appearance even in dark mode
                                            if isRecipeScan(json: entry.aiResultJSON) {
                                                VStack {
                                                    HStack {
                                                        Spacer()
                                                        Image(systemName: "book.pages.fill")
                                                            .font(.system(size: 16, weight: .semibold))
                                                            .foregroundColor(Color.black)
                                                            .padding(8)
                                                            .background(
                                                                Circle()
                                                                    .fill(Color.white.opacity(0.85))
                                                            )
                                                            .clipShape(Circle())
                                                            .padding(8)
                                                    }
                                                    Spacer()
                                                }
                                            }

                                            // UltraThin material overlay with text (bottom 30% of cardHeight)
                                            // Rule: Visual Design - Material always renders in light mode appearance even in dark mode
                                            VStack(alignment: .leading, spacing: 2) {
                                                // Rule: General Coding - Show description for both recipes and meals
                                                if isRecipeScan(json: entry.aiResultJSON),
                                                   let recipeDesc = getRecipeDescription(from: entry.aiResultJSON) {
                                                    // Recipe card: show recipe description
                                                    Text(recipeDesc)
                                                        .font(.subheadline)
                                                        .fontWeight(.semibold)
                                                        .foregroundColor(.white)
                                                        .lineLimit(2)
                                                        .multilineTextAlignment(.leading)
                                                } else if let mealSummary = getMealSummary(from: entry.aiResultJSON) {
                                                    // Meal card: show meal summary description
                                                    Text(mealSummary)
                                                        .font(.subheadline)
                                                        .fontWeight(.semibold)
                                                        .foregroundColor(.white)
                                                        .lineLimit(2)
                                                        .multilineTextAlignment(.leading)
                                                } else {
                                                    // Fallback: show carbs and date if no description available
                                                    Text((entry.carbEstimate.components(separatedBy: "·").first?.trimmingCharacters(in: .whitespaces) ?? entry.carbEstimate).replacingOccurrences(of: "carbs", with: "net carbs"))
                                                        .font(.subheadline)
                                                        .fontWeight(.bold)
                                                        .foregroundColor(.white)

                                                    Text(entry.date.formatted(.dateTime.month(.abbreviated).day()))
                                                        .font(.subheadline)
                                                        .foregroundColor(.white.opacity(0.8))
                                                }
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 5)
                                            .frame(width: cardWidth, height: cardHeight * 0.30, alignment: .leading)
                                            .background(
                                                Color.clear
                                                    .background(.ultraThinMaterial, in: Rectangle())
                                                    .environment(\.colorScheme, .light)
                                            )
                                        }
                                        .frame(width: cardWidth, height: cardHeight)
                                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                    .id(entry.id)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .scrollTargetLayout()
                        }
                        .frame(height: historyRowIdealHeight)
                        .scrollTargetBehavior(.viewAligned)
                        .scrollPosition(id: $currentCardID)
                        .contentMargins(.leading, cardSpacing) // Rule: Visual Design - Leading margin aligns first card with History title
                        .contentMargins(.trailing, peekAmount) // Rule: Visual Design - Subtle trailing peek of adjacent cards
                        .contentMargins(.vertical, 0)
                        .ignoresSafeArea(edges: .horizontal)
                        .onAppear {
                            // Reset scroll position when the ScrollView appears (e.g., navigating back)
                            currentCardID = nil
                            print("[UI] History row with entries shown")
                        }
                        .accessibilityIdentifier("history-row")
                    }
                }

                // MARK: - Capture Buttons
                // Rule: Visual Design - Buttons stick to bottom with minimal spacing above history
                Spacer()
                    .frame(height: 16) // Minimal spacing between history and buttons
                
                VStack(spacing: 0) {
                    // Buttons: Custom deep navy blue color (#0f3b63) for both light and dark mode
                    HStack(spacing: 12) {
                        // Capture Meal button - takes most of the width with subtle rounded corners
                        Button(action: {
                            print("[UI] Capture Meal tapped - checking usage limits")
                            
                            // Rule: General Coding - Check usage limit before opening capture flow
                            guard checkCaptureLimit() else { return }
                            
                            storage.clear()
                            showCaptureFlow = true
                        }) {
                            HStack {
                                Text("Capture Meal")
                                    .fontWeight(.semibold)
                                    .font(.title3)
                                Spacer()
                                Image(systemName: "camera.fill")
                                    .font(.title3)
                            }
                            .padding(.vertical, 22)
                            .padding(.horizontal, 30)
                            .foregroundColor(.white) // Rule: Visual Design - White text on custom navy background
                            .background(Color(red: 0x2a/255.0, green: 0x35/255.0, blue: 0x51/255.0)) // Rule: Visual Design - Hex color #2a3551
                            .clipShape(RoundedRectangle(cornerRadius: 60, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        
                        // Square Recipe button with Menu - subtle rounded corners
                        // Rule: SwiftUI-specific Patterns - Using native Menu for popover
                        Menu {
                            Button {
                                print("[UI] Recipe Menu -> Scan recipe - checking usage limits")
                                
                                // Rule: General Coding - Check usage limit before opening capture flow
                                guard checkCaptureLimit() else { return }
                                
                                recipeStorage.clear()
                                showRecipeScanFlow = true
                            } label: {
                                Label("Scan recipe", systemImage: "camera")
                            }
                            
                            Button {
                                print("[UI] Recipe Menu -> Enter recipe link - checking usage limits")
                                
                                // Rule: General Coding - Check usage limit before opening capture flow
                                guard checkCaptureLimit() else { return }
                                
                                showRecipeLinkView = true
                            } label: {
                                Label("Enter recipe link", systemImage: "link")
                            }
                        } label: {
                            // Square button with only icon, matching the height of Capture Meal button
                            Image(systemName: "fork.knife")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white) // Rule: Visual Design - White icon on custom navy background
                                .frame(width: 66, height: 66)
                                .background(Color(red: 0x2a/255.0, green: 0x35/255.0, blue: 0x51/255.0)) // Rule: Visual Design - Hex color #2a3551
                                .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(width: UIScreen.main.bounds.width * 0.9)
                }
                .padding(.bottom, 45) // Apply bottom padding to buttons
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(.container, edges: .bottom) // Make the outermost VStack extend to the very bottom
                }
            }
            .navigationDestination(isPresented: $showCaptureFlow) {
                Capture1View(storage: storage, onCancel: cancelCaptureFlow, historyStore: historyStore, usageManager: usageManager)
            }
            .navigationDestination(isPresented: $showRecipeScanFlow) {
                RecipeCaptureView(storage: recipeStorage, onCancel: cancelRecipeScanFlow, historyStore: historyStore, usageManager: usageManager)
            }
            .navigationDestination(isPresented: $showRecipeLinkView) {
                RecipeLinkView(
                    onDismiss: {
                        print("[Flow] Recipe link view dismissed by user.") // Rule: General Coding - Add debug logs
                        showRecipeLinkView = false
                    },
                    historyStore: historyStore, // Rule: State Management - Pass historyStore dependency
                    usageManager: usageManager
                )
            }
            .navigationDestination(isPresented: $showHistoryView) {
                // Rule: SwiftUI-specific Patterns - Navigate to HistoryView
                HistoryView()
                    .environmentObject(historyStore) // Rule: State Management - Pass environment object
            }
            .navigationDestination(isPresented: $showPlanView) {
                // Rule: SwiftUI-specific Patterns - Navigate to PlanView
                PlanView()
                    .environmentObject(historyStore)
                    .environmentObject(installationManager)
                    .environmentObject(subscriptionManager)
                    .environmentObject(usageManager)
            }
        }
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
                // Top bar with app title (left) and user icon (right)
                // Rule: General Coding - Clean UI by hiding elements when not on home screen
                if !showCaptureFlow && !showRecipeScanFlow && !showRecipeLinkView && !showHistoryView && !showPlanView {
                    HStack {
                        // App title - classic Apple style in top-left
                        // Rule: Visual Design - Large title typography for app branding
                        // Rule: Visual Design - Always render in black (light mode appearance) even in dark mode
                        Text("Carbetic")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.black)
                            .padding(.leading, 20) // Padding from left edge
                        
                        Spacer()
                        
                        // 🧪 TEMPORARY TEST BUTTON - Remove before shipping!
                        // Rule: General Coding - Debug button to test IntroOfferSheet without waiting for trial expiration
                        Button("Test") {
                            print("[DEBUG] Opening IntroOfferSheet for testing two-stage presentation")
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showIntroOfferSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .font(.caption)
                        .padding(.trailing, 8)
                        
                        // User icon button - positioned on right edge, larger and round
                        // Rule: Visual Design - Larger circular button for better touch target
                        // Rule: Visual Design - Always render in light mode appearance even in dark mode
                        Button(action: {
                            print("[UI] User icon tapped - opening PlanView") // Rule: General Coding - Add debug logs
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showPlanView = true // Rule: State Management - Reuse existing state variable
                        }) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.black)
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.85))
                                        .overlay(
                                            Circle()
                                                .stroke(Color.black.opacity(0.15), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 20) // Padding from right edge
                    }
                    .padding(.top, 15)
                }
            }
        }
        .sheet(isPresented: $showUpgradeSheet) {
            // Rule: Subscriptions - Use the same SubscriptionStoreSheet as PlanView
            // Rule: General Coding - Avoid duplication by reusing components
            SubscriptionStoreSheet(isPresented: $showUpgradeSheet)
                .presentationDetents([.large]) // Make the sheet go almost to the top of the screen
        }
        
        .sheet(isPresented: $showIntroOfferSheet) {
            // Rule: Subscriptions - Beautiful two-stage intro offer sheet
            // Rule: Visual Design - Starts compact (medium), expands to full (large) on button tap
            IntroOfferSheetWrapper(isPresented: $showIntroOfferSheet)
        }
        
        .sheet(isPresented: $showPromoWebView) {
            // Rule: General Coding - In-app web viewer for promotional links
            if let linkURL = promoBoxManager.config.linkURL, let url = URL(string: linkURL) {
                NavigationStack {
                    PromoWebView(url: url)
                        .navigationTitle("Carbetic")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    print("[UI] Promo web view dismissed") // Rule: General Coding - Add debug logs
                                    showPromoWebView = false
                                }
                            }
                        }
                }
                .presentationDetents([.large])
            }
        }
        
        .sheet(isPresented: $showShareSheet) {
            // Rule: SwiftUI-specific Patterns - Use native share sheet
            if let shareText = promoBoxManager.config.shareText {
                ShareSheet(items: [shareText])
            }
        }

        .sheet(isPresented: $showRecipeHistoryResult) {
            NavigationStack {
                RecipeResultView(
                    resultText: $selectedHistoryResultJSON,
                    isLoading: $selectedIsLoading,
                    recipeImage: selectedHistoryImage,
                    recipeURL: selectedHistoryRecipeURL,
                    onDone: { showRecipeHistoryResult = false },
                    showHomeInQuickAccessBar: false
                )
            }
            .presentationDetents([.large])
        }

        .sheet(isPresented: $showMealHistoryResult) {
            NavigationStack {
                ResultView(
                    resultText: $selectedHistoryResultJSON,
                    isLoading: $selectedIsLoading,
                    onDone: { showMealHistoryResult = false },
                    showHomeInQuickAccessBar: false
                )
            }
            .presentationDetents([.large])
        }
        
        // Rule: Subscriptions - Alert when daily limit is reached
        .alert("You have reached your daily limit", isPresented: $showLimitReachedAlert) {
            Button("Upgrade to unlimited") {
                print("[UI] Upgrade button tapped from limit alert - opening store sheet") // Rule: General Coding - Add debug logs
                showUpgradeSheet = true // Rule: Subscriptions - Open store sheet directly instead of PlanView
            }
            Button("Cancel", role: .cancel) {
                print("[UI] Limit alert dismissed")
            }
        } message: {
            Text("Upgrade to continue capturing meals and recipes")
        }
        
        // Rule: General Coding - Overlay when no internet connection is available
        // Full-screen blur with centered message and SF Symbol
        .overlay {
            if showNoInternetOverlay {
                ZStack {
                    // Blur background - makes entire screen blurry
                    Color.clear
                        .background(.ultraThinMaterial)
                        .ignoresSafeArea()
                    
                    // Centered card with .thinMaterial appearance
                    VStack(spacing: 20) {
                        // SF Symbol
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        
                        // Message
                        VStack(spacing: 8) {
                            Text("No Internet Connection")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Please check your connection and try again")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        // Ok button
                        Button {
                            print("[UI] No internet overlay dismissed")
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                showNoInternetOverlay = false
                            }
                        } label: {
                            Text("Ok")
                                .fontWeight(.semibold)
                                .frame(width: 100)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(40)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                    .padding(.horizontal, 40)
                    .scaleEffect(showNoInternetOverlay ? 1.0 : 0.9)
                    .opacity(showNoInternetOverlay ? 1.0 : 0.0)
                }
                .transition(.opacity)
            }
        }
        
        // Rule: General Coding - Fetch AI model configuration when app starts
        .onAppear {
            print("[ContentView] View appeared, fetching AI model configuration...")
            Task {
                await AIModelConfigManager.shared.fetchConfiguration()
                print("[ContentView] AI model configuration fetch completed")
            }
            
            // Rule: General Coding - Fetch promotional box configuration when app starts
            print("[ContentView] Fetching promotional box configuration...")
            Task {
                await promoBoxManager.fetchConfiguration()
                print("[ContentView] Promotional box configuration fetch completed")
            }
        }
    }
}

#Preview("Empty History - First Time User Box") {
    // Rule: SwiftUI-specific Patterns - Preview with empty history to show instructional box
    // Rule: General Coding - Preview demonstrates UI state without modifying data
    // Create a fresh, isolated store instance for this preview only
    let emptyStore = ScanHistoryStore()
    
    return ContentView()
        .environmentObject(emptyStore)
        .environmentObject(UserInstallationManager())
        .environmentObject(SubscriptionManager())
        .environmentObject(CaptureUsageManager())
        .environmentObject(NetworkMonitor())
        .environmentObject(PromoBoxManager.shared)
}

#Preview("With History - Subscription Box") {
    // Rule: SwiftUI-specific Patterns - Wrapper view to simulate "has entries" state for preview
    // Rule: General Coding - Preview only demonstrates UI, doesn't modify actual data
    // IMPORTANT: Each preview creates its own isolated store to prevent cross-contamination
    struct PreviewContainer: View {
        // Create a fresh, isolated store instance for this preview only
        @StateObject private var store = ScanHistoryStore()
        @State private var hasAddedEntry = false // Prevent duplicate entries on re-render
        
        var body: some View {
            ContentView()
                .environmentObject(store)
                .environmentObject(UserInstallationManager())
                .environmentObject(SubscriptionManager())
                .environmentObject(CaptureUsageManager())
                .environmentObject(NetworkMonitor())
                .environmentObject(PromoBoxManager.shared)
                .onAppear {
                    // Only add entry once, not on every render
                    guard !hasAddedEntry else { return }
                    hasAddedEntry = true
                    
                    // Add a single entry synchronously to trigger subscription box UI
                    // This is ONLY for preview visualization
                    let image = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100)).image { context in
                        UIColor.systemBlue.setFill()
                        context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
                    }
                    
                    Task { @MainActor in
                        await store.addEntry(
                            firstImage: image,
                            carbEstimate: "Preview",
                            aiResultJSON: nil,
                            recipeURLString: nil
                        )
                    }
                }
        }
    }
    
    return PreviewContainer()
}

#Preview("With History - Promotional Box") {
    // Rule: SwiftUI-specific Patterns - Wrapper view to simulate subscribed user with promo box
    // Rule: General Coding - Preview demonstrates promotional box UI with dynamic content
    struct PreviewContainer: View {
        // Create a fresh, isolated store instance for this preview only
        @StateObject private var store = ScanHistoryStore()
        @StateObject private var subscriptionManager = SubscriptionManager()
        @StateObject private var promoBoxManager = PromoBoxManager.shared
        @State private var hasAddedEntry = false // Prevent duplicate entries on re-render
        @State private var hasConfiguredPromoBox = false // Prevent duplicate config
        
        var body: some View {
            ContentView()
                .environmentObject(store)
                .environmentObject(UserInstallationManager())
                .environmentObject(subscriptionManager)
                .environmentObject(CaptureUsageManager())
                .environmentObject(NetworkMonitor())
                .environmentObject(promoBoxManager)
                .onAppear {
                    // Only add entry once, not on every render
                    guard !hasAddedEntry else { return }
                    hasAddedEntry = true
                    
                    // Add a single entry synchronously to trigger promo box UI
                    // This is ONLY for preview visualization
                    let image = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100)).image { context in
                        UIColor.systemGreen.setFill()
                        context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
                    }
                    
                    Task { @MainActor in
                        await store.addEntry(
                            firstImage: image,
                            carbEstimate: "Preview",
                            aiResultJSON: nil,
                            recipeURLString: nil
                        )
                        
                        // Configure promotional box for preview
                        guard !hasConfiguredPromoBox else { return }
                        hasConfiguredPromoBox = true
                        
                        // Manually set promo box config for preview
                        // Rule: General Coding - Simulate Firebase config for preview purposes
                        promoBoxManager.setConfigForPreview(PromoBoxConfig(
                            iconType: .sfSymbol("star.fill"),
                            title: "New feature available!",
                            subtitle: "Check out our improved AI model",
                            linkURL: "https://www.apple.com", // Example link
                            enableShare: false, // Set to true to test share functionality
                            shareText: "Check out Carbetic - the best carb tracking app!", // Example share text
                            isEnabled: true
                        ))
                        
                        // Simulate Standard subscription for preview
                        // Note: This is a preview-only hack; in real app, subscription status comes from StoreKit
                        print("[Preview] Simulating Standard subscription for promo box preview")
                    }
                }
        }
    }
    
    return PreviewContainer()
}

#Preview("Intro Offer Sheet") {
    // Rule: SwiftUI-specific Patterns - Preview the beautiful intro offer sheet
    // Rule: General Coding - Isolated preview to show sheet design
    struct PreviewContainer: View {
        @State private var showSheet = true
        
        var body: some View {
            Color.gray.opacity(0.2)
                .ignoresSafeArea()
                .sheet(isPresented: $showSheet) {
                    IntroOfferSheet(isPresented: $showSheet, skipTrialExpiredStage: false)
                }
        }
    }
    
    return PreviewContainer()
}

// MARK: - IntroOfferSheetWrapper

/// Wrapper for IntroOfferSheet that manages dynamic presentation detents
/// Rule: SwiftUI-specific Patterns - Controls sheet size transitions from medium to large
/// Rule: Visual Design - Smooth animation when expanding from compact to full view
/// Rule: Apple Guidelines - Modal presentation with explicit dismissal only via close button
struct IntroOfferSheetWrapper: View {
    @Binding var isPresented: Bool
    @State private var currentDetent: PresentationDetent = .medium
    
    var body: some View {
        IntroOfferSheetBridge(
            isPresented: $isPresented,
            currentDetent: $currentDetent
        )
        .presentationDetents([.medium, .large], selection: $currentDetent)
        .presentationDragIndicator(.hidden) // Hide drag indicator
        // Note: interactiveDismissDisabled is now handled in IntroOfferSheetBridge for dynamic control
        .presentationBackgroundInteraction(.disabled) // Disable interaction with content behind sheet
        .presentationBackground(Color.black.opacity(0.5)) // Rule: Visual Design - Increased dimming with semi-transparent black overlay
    }
}

/// Bridge view that creates IntroOfferSheet with expansion callback
/// Rule: State Management - Manages communication between sheet content and detent controller
struct IntroOfferSheetBridge: View {
    @Binding var isPresented: Bool
    @Binding var currentDetent: PresentationDetent
    @State private var internalIsExpanded = false
    @State private var isDismissDisabled = true // Rule: Visual Design - Only disable dismiss for compact view
    
    var body: some View {
        IntroDynamicOfferSheet(
            isPresented: $isPresented,
            isExpanded: $internalIsExpanded,
            onExpansionChange: { shouldExpand in
                if shouldExpand {
                    print("[IntroOfferSheetBridge] Expanding sheet detent from medium to large")
                    // Rule: Visual Design - Smooth spring animation for natural expansion
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentDetent = .large
                        // Rule: Visual Design - Enable swipe-to-dismiss once expanded to large
                        isDismissDisabled = false
                    }
                }
            }
        )
        .interactiveDismissDisabled(isDismissDisabled) // Rule: Visual Design - Dynamic dismiss control based on expansion state
        .onChange(of: internalIsExpanded) { oldValue, newValue in
            // When internal expansion changes, update detent and dismiss state
            if newValue && currentDetent == .medium {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    currentDetent = .large
                    // Enable swipe-to-dismiss for large view
                    isDismissDisabled = false
                }
            }
        }
    }
}

/// Dynamic version of IntroOfferSheet with callback for expansion
/// Rule: General Coding - Uses same visual design as IntroOfferSheet with added detent control
struct IntroDynamicOfferSheet: View {
    @Binding var isPresented: Bool
    @Binding var isExpanded: Bool
    let onExpansionChange: (Bool) -> Void
    
    @State private var showAllPlans = false
    @State private var standardProduct: Product?
    @Environment(\.colorScheme) private var colorScheme
    
    // Constants matching IntroOfferSheet
    private let standardProductID = "PremiumStandardSub"
    private let gradientStart = Color(red: 0x0b/255.0, green: 0x6d/255.0, blue: 0xd1/255.0)
    private let gradientEnd = Color(red: 0x3d/255.0, green: 0x88/255.0, blue: 0xdc/255.0)
    private let buttonColor = Color(red: 0x0b/255.0, green: 0x6d/255.0, blue: 0xd1/255.0)
    
    var body: some View {
        Group {
            if isExpanded {
                // STAGE 2: Full offer with gradient
                fullOfferView
            } else {
                // STAGE 1: Compact trial expired
                compactView
            }
        }
        .onAppear {
            loadProduct()
        }
        .onInAppPurchaseCompletion { product, result in
            if case .success(.success(let verificationResult)) = result {
                switch verificationResult {
                case .verified(let transaction):
                    print("[IntroOfferSheet] Purchase successful: \(transaction.productID)")
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    isPresented = false
                case .unverified(_, let error):
                    print("[IntroOfferSheet] Purchase unverified: \(error)")
                }
            }
        }
    }
    
    // MARK: - Compact View
    
    private var compactView: some View {
        ZStack {
            (colorScheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                // App logo with gradient overlay effect
                // Rule: Visual Design - Use app logo instead of SF Symbol for brand consistency
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [gradientStart.opacity(0.3), gradientEnd.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                
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
                
                VStack(spacing: 12) {
                    if let product = standardProduct,
                       let introOffer = product.subscription?.introductoryOffer {
                        Button {
                            print("[IntroOfferSheet] Plans starting button tapped - expanding")
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            expandToFull()
                        } label: {
                            Text("Plans starting at \(introOffer.displayPrice)/month")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(buttonColor)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    } else if let product = standardProduct {
                        Button {
                            print("[IntroOfferSheet] Plans starting button tapped - expanding")
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            expandToFull()
                        } label: {
                            Text("Plans starting at \(product.displayPrice)/month")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(buttonColor)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    } else {
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
                        .frame(height: 56)
                        .background(buttonColor.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(.horizontal, 24) // Rule: Visual Design - Reduced from 32 to 24 for wider button
                .padding(.bottom, 20)
            }
            
            // Close button
            // Rule: Apple Guidelines - Users must always be able to dismiss sheets
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
        .sheet(isPresented: $showAllPlans) {
            SubscriptionStoreSheet(
                isPresented: $showAllPlans,
                customTitle: "Choose your plan"
            )
        }
    }
    
    // MARK: - Full Offer View
    
    private var fullOfferView: some View {
        ZStack {
            (colorScheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    LinearGradient(
                        colors: [gradientStart, gradientEnd],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .ignoresSafeArea(edges: .top)
                    
                    VStack(spacing: 12) {
                        Spacer()
                        
                        Text("Introductory offer")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.7))
                        
                        if let product = standardProduct,
                           let introOffer = product.subscription?.introductoryOffer {
                            Text("Join for only\n\(introOffer.displayPrice)/month")
                                .font(.system(size: 40, weight: .heavy))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 2)
                                .shadow(color: Color.white.opacity(0.3), radius: 1, x: 0, y: -0.5)
                                .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 3)
                        } else if let product = standardProduct {
                            Text("Get Carbetic for only\n\(product.displayPrice)/Month")
                                .font(.system(size: 40, weight: .heavy))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 2)
                                .shadow(color: Color.white.opacity(0.3), radius: 1, x: 0, y: -0.5)
                                .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 3)
                        } else {
                            Text("Get Carbetic")
                                .font(.system(size: 40, weight: .heavy))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 2)
                                .shadow(color: Color.white.opacity(0.3), radius: 1, x: 0, y: -0.5)
                                .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 3)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 20)
                }
                .frame(height: UIScreen.main.bounds.height * 0.50)
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    Text("Includes 10 daily analyses for meals and recipes")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 32)
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        if let product = standardProduct,
                           let introOffer = product.subscription?.introductoryOffer {
                            Text(formatIntroOffer(product: product, introOffer: introOffer))
                                .font(.footnote) // Rule: Visual Design - Slightly increased from .caption to .footnote for better readability
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24) // Rule: Visual Design - Reduced from 32 to 24 for wider button
                                .padding(.bottom, 8)
                        } else if let product = standardProduct {
                            Text("Subscribe for \(product.displayPrice)/Month")
                                .font(.footnote) // Rule: Visual Design - Slightly increased from .caption to .footnote for better readability
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24) // Rule: Visual Design - Reduced from 32 to 24 for wider button
                                .padding(.bottom, 8)
                        } else {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .padding(.bottom, 8)
                        }
                        
                        Button {
                            print("[IntroOfferSheet] Accept Offer tapped")
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            acceptOffer()
                        } label: {
                            Text("Accept Offer")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(buttonColor)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(standardProduct == nil)
                        
                        Spacer()
                            .frame(height: 16)
                        
                        Button {
                            print("[IntroOfferSheet] See All Plans tapped")
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showAllPlans = true
                        } label: {
                            Text("See All Plans")
                                .font(.callout)
                                .fontWeight(.medium)
                                .foregroundColor(colorScheme == .dark ? .white : buttonColor)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24) // Rule: Visual Design - Reduced from 32 to 24 for wider button
                    .padding(.bottom, 20)
                }
            }
            
            // Close button
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
                .padding(.top, 16)
                .padding(.trailing, 16)
                
                Spacer()
            }
            .zIndex(999)
        }
        .sheet(isPresented: $showAllPlans) {
            SubscriptionStoreSheet(
                isPresented: $showAllPlans,
                customTitle: "Choose your plan"
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func expandToFull() {
        print("[IntroOfferSheet] Triggering expansion")
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isExpanded = true
        }
        onExpansionChange(true)
    }
    
    private func loadProduct() {
        Task {
            do {
                let products = try await Product.products(for: [standardProductID])
                if let product = products.first {
                    await MainActor.run {
                        standardProduct = product
                        print("[IntroOfferSheet] Loaded product: \(product.displayName) - \(product.displayPrice)")
                        if let intro = product.subscription?.introductoryOffer {
                            print("[IntroOfferSheet] Introductory offer available: \(intro.displayPrice)")
                        }
                    }
                }
            } catch {
                print("[IntroOfferSheet] ❌ Failed to load product: \(error)")
            }
        }
    }
    
    private func formatIntroOffer(product: Product, introOffer: Product.SubscriptionOffer) -> String {
        let introPriceString = introOffer.displayPrice
        let regularPriceString = product.displayPrice
        let period = introOffer.period
        let periodValue = period.value
        
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
        
        return "\(durationText) for \(introPriceString)/Month, then \(regularPriceString)/Month"
    }
    
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
                case .userCancelled:
                    print("[IntroOfferSheet] User cancelled purchase")
                case .pending:
                    print("[IntroOfferSheet] Purchase pending")
                @unknown default:
                    print("[IntroOfferSheet] Unknown purchase result")
                }
            } catch {
                print("[IntroOfferSheet] ❌ Purchase failed: \(error)")
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw NSError(domain: "IntroOfferSheet", code: 1, userInfo: [NSLocalizedDescriptionKey: "Transaction verification failed"])
        case .verified(let safe):
            return safe
        }
    }
}

// MARK: - ShareSheet
// Rule: No Modules - Defining view within the same file for simplicity
// Rule: SwiftUI-specific Patterns - UIActivityViewController wrapper for native sharing
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        print("[ShareSheet] Presenting share sheet with items: \(items)") // Rule: General Coding - Add debug logs
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - PromoWebView
// Rule: No Modules - Defining view within the same file for simplicity
// Rule: SwiftUI-specific Patterns - Simple web view wrapper using WKWebView
struct PromoWebView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        print("[PromoWebView] Loading URL: \(url.absoluteString)") // Rule: General Coding - Add debug logs
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        webView.load(request)
    }
}

// MARK: - UpgradeSheetView
// Rule: No Modules - Defining view within the same file for simplicity
struct UpgradeSheetView: View {
    // Rule: SwiftUI-specific Patterns - Use @Binding for two-way data flow
    @Binding var showUpgradeSheet: Bool

    // Rule: General Coding - Use a constant for clarity and easy modification
    // Updated with user's specific product IDs
    let productIdentifiers: Set<String> = ["PremiumStandardSub", "PremiumSub"]

    var body: some View {
        NavigationStack { // Embed sheet content in a NavigationStack for toolbar
            VStack {
                // Rule: Subscriptions - Use native SubscriptionStoreView
                SubscriptionStoreView(productIDs: productIdentifiers) {
                    // Custom header content for a beautiful appearance, inspired by Apple's documentation
                    VStack(spacing: 15) {
                        Image(systemName: "sparkles")
                            .font(.largeTitle)
                            .foregroundStyle(
                                LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                        Text("Unlock Unlimited Carb Tracking")
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Text("Go Standard to get unlimited scans, detailed insights, and more features to master your carb intake!")
                            .font(.callout)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 20) // Add some padding around the custom header
                }
                // These modifiers require iOS 17.0+.
                // If you continue to see errors, please verify your project's minimum deployment target.
                .storeButton(.visible, for: .restorePurchases) // Show restore button
                .storeButton(.hidden, for: .cancellation)     // Hide cancellation button
                // .storeButton(.hidden, for: .policies) - Removed, as it's not a standard direct option for StoreButton.
                // Removed all .subscriptionStorePolicy lines because these are the primary source of "no member" errors if deployment target is too low.
                // If your target is indeed iOS 17.0+, and you still want custom policy visibility,
                // you might need to ensure Xcode is up-to-date and perform a clean build.
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { // Rule: General Coding - Apple Design/UI/UX guidelines (e.g., standard "Done" button)
                        print("[UI] Upgrade sheet Done button tapped.") // Rule: General Coding - Add debug logs
                        showUpgradeSheet = false
                    }
                }
            }
        }
        // Removed: .environment(\.appStore, .shared)
        // This environment key is often not strictly necessary for SubscriptionStoreView and
        // was causing "Cannot infer contextual base" and "no member 'appStore'" errors.
        // SubscriptionStoreView typically picks up the correct App Store environment automatically.
    }
}

