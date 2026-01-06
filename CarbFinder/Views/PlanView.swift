//
//  PlanView.swift
//  CarbFinder
//
//  Created by Diego Szekely on 13.11.25.
//

import SwiftUI
import StoreKit
import Combine
import SafariServices

/// View for managing user's subscription plan and trial period
/// Rule: State Management - Uses @EnvironmentObject for app-wide managers
struct PlanView: View {
    
    // MARK: - Properties
    
    /// Installation manager from app environment
    /// Rule: State Management - Use @EnvironmentObject for app-wide state
    @EnvironmentObject private var installationManager: UserInstallationManager
    
    /// Subscription manager from app environment
    /// Rule: State Management - Use @EnvironmentObject for subscription state
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    
    /// Usage manager from app environment
    /// Rule: State Management - Use @EnvironmentObject for usage tracking
    @EnvironmentObject private var usageManager: CaptureUsageManager
    
    /// AI model config manager for model preference
    /// Rule: State Management - Access singleton as @State to trigger UI updates
    @State private var aiConfigManager = AIModelConfigManager.shared
    
    /// Environment for color scheme detection
    @Environment(\.colorScheme) private var colorScheme
    
    /// State for showing subscription sheet
    /// Rule: State Management - Local @State for sheet presentation
    @State private var showingSubscriptionSheet = false
    
    /// State for showing intro offer sheet
    /// Rule: State Management - Local @State for intro offer sheet presentation
    @State private var showingIntroOfferSheet = false
    
    /// State for controlling if intro offer should skip trial expired stage
    /// Rule: State Management - Controls initial presentation of intro offer sheet
    @State private var skipTrialExpiredStage = false
    
    /// State for showing unlimited upgrade sheet
    /// Rule: State Management - Local @State for unlimited upgrade sheet presentation
    @State private var showingUnlimitedUpgradeSheet = false
    
    /// Environment for dismissing the sheet
    /// Rule: State Management - Use @Environment for dismiss action
    @Environment(\.dismiss) private var dismiss
    
    /// State for showing restore alert
    /// Rule: State Management - Local @State for alert presentation
    @State private var showingRestoreAlert = false
    
    /// State for restore alert message
    /// Rule: State Management - Local @State for alert content
    @State private var restoreAlertMessage = ""
    
    /// State for restore operation in progress
    /// Rule: State Management - Local @State for loading indicator
    @State private var isRestoringPurchases = false
    
    /// State for showing privacy/terms action sheet
    /// Rule: State Management - Local @State for action sheet presentation
    @State private var showingLegalActionSheet = false
    
    /// State for showing web view sheet
    /// Rule: State Management - Local @State for web view presentation
    @State private var showingWebView = false
    
    /// URL to display in web view
    /// Rule: State Management - Local @State for web view URL
    @State private var webViewURL: URL?
    
    /// User preference for showing Loop app integration
    /// Rule: State Management - Use @AppStorage for persisted user preferences
    @AppStorage("showLoopIntegration") private var showLoopIntegration: Bool = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // MARK: - Loading State
                    // Rule: General Coding - Show loading indicator while Firebase/StoreKit initialize
                    // This prevents race condition where user opens view before data is ready
                    if installationManager.isLoading || subscriptionManager.isLoading {
                        loadingView
                            .padding(.horizontal)
                            .padding(.top, 8)
                    }
                    
                    // MARK: - Subscription Status Card
                    // Rule: General Coding - Show current subscription status prominently
                    if !installationManager.isLoading && !subscriptionManager.isLoading {
                        subscriptionStatusCard
                            .padding(.horizontal)
                            .padding(.top, 8)
                    }
                    

                    
                    // MARK: - Privacy Policy & Terms Card
                    // Rule: General Coding - Provide access to legal documents
                    if !installationManager.isLoading && !subscriptionManager.isLoading {
                        privacyAndTermsCard
                            .padding(.horizontal)
                    }
                    
                    // MARK: - AI Model Preference Card
                    // Rule: General Coding - Allow users to choose between fast and accurate models
                    if !installationManager.isLoading && !subscriptionManager.isLoading {
                        aiModelPreferenceCard
                            .padding(.horizontal)
                    }
                    
                    // MARK: - Loop Integration Card
                    // Rule: General Coding - Allow users to enable/disable Loop app integration
                    if !installationManager.isLoading && !subscriptionManager.isLoading {
                        loopIntegrationCard
                            .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 20)
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.large) // Rule: General Coding - Apple Design guidelines for large titles
            // Rule: General Coding - Use safeAreaInset to pin upgrade button/link to bottom
            .safeAreaInset(edge: .bottom) {
                if !installationManager.isLoading && !subscriptionManager.isLoading {
                    // MARK: - Upgrade Button
                    // Rule: General Coding - Show upgrade button for non-unlimited users
                    if subscriptionManager.currentTier != .unlimited {
                        upgradeButton
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                    }
                }
            }
        }
        .sheet(isPresented: $showingSubscriptionSheet) {
            // Rule: Subscriptions - Present subscription store in separate sheet
            // Rule: General Coding - Show custom "Choose your plan" title for upgrade context
            SubscriptionStoreSheet(isPresented: $showingSubscriptionSheet, customTitle: "Choose your plan")
        }
        .sheet(isPresented: $showingIntroOfferSheet) {
            // Rule: Subscriptions - Present intro offer sheet for trial expired users
            // Rule: General Coding - Highlight Standard plan with introductory pricing
            // Rule: State Management - Control initial stage based on context
            IntroOfferSheet(isPresented: $showingIntroOfferSheet, skipTrialExpiredStage: skipTrialExpiredStage)
        }
        .sheet(isPresented: $showingUnlimitedUpgradeSheet) {
            // Rule: Subscriptions - Present unlimited upgrade sheet for Standard users
            // Rule: General Coding - Show promotional view for Unlimited plan
            UnlimitedUpgradeSheet(isPresented: $showingUnlimitedUpgradeSheet)
        }
        .alert("Restore Purchases", isPresented: $showingRestoreAlert) {
            // Rule: General Coding - Provide clear user feedback for restore operation
            Button("OK", role: .cancel) { }
        } message: {
            Text(restoreAlertMessage)
        }
        .confirmationDialog("Legal Information", isPresented: $showingLegalActionSheet, titleVisibility: .visible) {
            // Rule: General Coding - Action sheet for choosing between privacy policy and terms
            Button("Privacy Policy") {
                print("[PlanView] Privacy Policy selected")
                webViewURL = URL(string: "https://sites.google.com/view/carbetic-privacy-policy/startseite")
                showingWebView = true
            }
            
            Button("Terms of Use") {
                print("[PlanView] Terms and Conditions selected")
                webViewURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
                showingWebView = true
            }
            
            Button("Cancel", role: .cancel) {
                print("[PlanView] Legal action sheet cancelled")
            }
        }
        .sheet(isPresented: $showingWebView) {
            // Rule: General Coding - Present web view in sheet for in-app browsing
            if let url = webViewURL {
                SafariView(url: url)
            }
        }
    }
    
    // MARK: - Subscription Status Card
    
    /// Combined card showing plan and usage in Apple Settings style
    /// Rule: General Coding - Apple Settings design pattern with grouped rows and dividers
    private var subscriptionStatusCard: some View {
        VStack(spacing: 0) {
            // Row 1: Manage Plan with usage info - non-clickable but visually consistent
            // Rule: General Coding - Non-interactive row should maintain same visual style
            HStack(spacing: 12) {
                // Person icon - twice as large (64pt)
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 55)) //55 is correct for now
                    .foregroundStyle(.secondary)
                
                // Text content
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your plan")
                        .font(.body)
                        .bold()
                        .foregroundStyle(.primary)
                    
                    // Usage text or "No limit"
                    Text(usageText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Divider
            Divider()
                .padding(.leading, 60)
            
            // Row 2: Subscription tier (always tappable to open StoreKit sheet)
            // Rule: General Coding - Show intro offer for trial expired, full sheet otherwise
            Button {
                print("[PlanView] Subscription tier tapped")
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                
                // Check if trial expired and on free tier
                let isTrialExpired = subscriptionManager.currentTier == .free && !installationManager.isWithinTrialPeriod()
                
                if isTrialExpired {
                    // Show intro offer sheet WITH trial expired stage
                    skipTrialExpiredStage = false
                    showingIntroOfferSheet = true
                } else if subscriptionManager.currentTier == .free {
                    // Free tier but within trial - show intro offer WITHOUT trial expired stage
                    skipTrialExpiredStage = true
                    showingIntroOfferSheet = true
                } else {
                    // Already subscribed - show full subscription sheet
                    showingSubscriptionSheet = true
                }
            } label: {
                HStack(spacing: 12) {
                    // App logo - 30% smaller (22.4pt, rounded to 22pt)
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 25, height: 25)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    
                    // Tier name
                    Text(tierDisplayText)
                        .font(.body)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    // Chevron always visible
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Divider
            Divider()
                .padding(.leading, 60)
            
            // Row 3: Restore Purchases
            // Rule: Subscriptions - Apple requires restore purchases for compliance
            Button {
                print("[PlanView] Restore purchases tapped")
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                restorePurchases()
            } label: {
                HStack(spacing: 12) {
                    // Restore icon - same size as gift card icon (20pt)
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 25))
                        .foregroundStyle(.secondary)
                        .frame(width: 25)
                    
                    // Text
                    Text("Restore Purchases")
                        .font(.body)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    // Show loading spinner if restoring, otherwise show chevron
                    if isRestoringPurchases {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isRestoringPurchases)
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6))
        )
    }
    
    /// Usage text for the manage plan row
    /// Rule: General Coding - Dynamic text based on tier and usage
    private var usageText: String {
        // Check if unlimited tier
        if subscriptionManager.currentTier == .unlimited {
            return "No limit"
        }
        
        // Check if trial is active
        let isTrialActive = installationManager.isWithinTrialPeriod()
        let isFreeTier = subscriptionManager.currentTier == .free
        
        // For free trial and standard users, show usage
        if (isFreeTier && isTrialActive) || subscriptionManager.currentTier == .premium {
            let used = usageManager.capturesUsedToday
            let limit = subscriptionManager.currentTier.dailyCaptureLimit
            let remaining = limit - used
            
            if remaining <= 0 {
                return "Daily limit reached"
            } else if remaining == 1 {
                return "1 capture remaining"
            } else {
                return "\(remaining) analyses remaining today"
            }
        }
        
        // Trial expired
        return "Trial expired"
    }
    
    /// Tier display text for subscription row
    /// Rule: General Coding - Show appropriate tier text with trial info
    private var tierDisplayText: String {
        let isTrialActive = installationManager.isWithinTrialPeriod()
        let isFreeTier = subscriptionManager.currentTier == .free
        
        if isFreeTier && isTrialActive {
            let days = installationManager.daysRemainingInTrial()
            return "Free Trial (\(days) \(days == 1 ? "day" : "days") left)"
        } else if isFreeTier && !isTrialActive {
            // Show "Subscribe now" instead of "Trial Expired"
            return "Subscribe now"
        } else {
            return subscriptionManager.currentTier.displayName
        }
    }
    
    // MARK: - Upgrade Button
    
    /// Button to open subscription sheet
    /// Rule: General Coding - Prominent call-to-action for upgrades (matches ContentView capture button style)
    private var upgradeButton: some View {
        let trialExpired = subscriptionManager.currentTier == .free && !installationManager.isWithinTrialPeriod()
        let buttonText: String = {
            if trialExpired {
                return "Subscribe to Continue"
            } else if subscriptionManager.currentTier == .free {
                return "Subscribe"
            } else {
                return "Upgrade to Unlimited"
            }
        }()
        
        return Button {
            print("[PlanView] Upgrade button tapped")
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            
            // Show intro offer sheet for trial expired/free tier users
            // Show unlimited upgrade sheet for Standard users
            if trialExpired {
                // Trial expired - show WITH trial expired stage
                skipTrialExpiredStage = false
                showingIntroOfferSheet = true
            } else if subscriptionManager.currentTier == .free {
                // Free tier - show WITHOUT trial expired stage
                skipTrialExpiredStage = true
                showingIntroOfferSheet = true
            } else {
                // Standard tier - show unlimited upgrade sheet
                showingUnlimitedUpgradeSheet = true
            }
        } label: {
            HStack {
                Image(systemName: "star.fill")
                    .font(.headline)
                
                Text(buttonText)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                // Use same dark blue gradient as ContentView capture button
                LinearGradient(
                    colors: [
                        Color(red: 0x0F/255.0, green: 0x3D/255.0, blue: 0x66/255.0), // #0F3D66
                        Color(red: 0x0B/255.0, green: 0x2A/255.0, blue: 0x4A/255.0)  // #0B2A4A
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    
    // MARK: - Privacy Policy & Terms Card
    
    /// Card for accessing privacy policy and terms and conditions
    /// Rule: General Coding - Provide easy access to legal documents
    /// Rule: General Coding - Apple Settings design pattern with description text
    private var privacyAndTermsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Main button box
            Button {
                print("[PlanView] Privacy & Terms card tapped")
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showingLegalActionSheet = true
            } label: {
                HStack(spacing: 12) {
                    // Info icon
                    Image(systemName: "info.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    
                    // Text
                    Text("Legal information")
                        .font(.body)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6))
            )
            
            // Description text below the box
            Text("Open the Privacy Policy and the Terms & Use (EULA)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 15)
        }
    }
    
    /// Performs the restore purchases operation
    /// Rule: Subscriptions - Use StoreKit 2's AppStore.sync() to restore purchases
    /// Rule: General Coding - Provide clear feedback for success and failure cases
    private func restorePurchases() {
        // Rule: General Coding - Prevent multiple simultaneous restore operations
        guard !isRestoringPurchases else { return }
        
        isRestoringPurchases = true
        print("[PlanView] Starting restore purchases operation...")
        
        Task {
            do {
                // Rule: Subscriptions - Use SubscriptionManager's restore method which calls AppStore.sync()
                try await subscriptionManager.restorePurchases()
                
                // Rule: General Coding - Provide success feedback to user
                await MainActor.run {
                    print("[PlanView] Restore purchases succeeded. Current tier: \(subscriptionManager.currentTier.displayName)")
                    
                    // Determine appropriate message based on outcome
                    if subscriptionManager.currentTier == .free {
                        restoreAlertMessage = "No previous purchases found. If you believe this is an error, please contact support."
                    } else {
                        restoreAlertMessage = "Your purchases have been restored successfully. You now have access to \(subscriptionManager.currentTier.displayName)."
                    }
                    
                    isRestoringPurchases = false
                    showingRestoreAlert = true
                }
            } catch {
                // Rule: General Coding - Handle errors gracefully with clear messaging
                await MainActor.run {
                    print("[PlanView] Restore purchases failed: \(error.localizedDescription)")
                    restoreAlertMessage = "Unable to restore purchases. Please check your internet connection and try again."
                    isRestoringPurchases = false
                    showingRestoreAlert = true
                }
            }
        }
    }
    
    // MARK: - AI Model Preference Card
    
    /// Card for selecting AI model preference with Apple-style toggle
    /// Rule: General Coding - Simple toggle UI with description below, no border, reduced padding
    private var aiModelPreferenceCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Main toggle box
            HStack(spacing: 14) {
                // Text content on the left - same font as other rows
                Text("Prioritize faster analysis")
                    .font(.body)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Toggle switch on the right
                // Rule: General Coding - Use native Toggle for Apple design consistency
                Toggle("", isOn: fastModeBinding)
                    .labelsHidden()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6))
            )
            
            // Description text below the box
            Text("Significantly reduces analysis time (~by a factor of 3). This might lead to slightly less accurate results")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 15)
        }
    }
    
    /// Computed binding for fast mode toggle
    /// Rule: State Management - Convert between toggle bool and enum preference
    private var fastModeBinding: Binding<Bool> {
        Binding(
            get: {
                // Toggle is ON when preference is FAST
                aiConfigManager.modelPreference == .fast
            },
            set: { isOn in
                // ON = fast, OFF = accurate
                let newPreference: AIModelPreference = isOn ? .fast : .accurate
                print("[PlanView] Model preference toggled to: \(newPreference.displayName)")
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                aiConfigManager.modelPreference = newPreference
            }
        )
    }
    
    // MARK: - Loop Integration Card
    
    /// Card for enabling/disabling Loop app integration with Apple-style toggle
    /// Rule: General Coding - Simple toggle UI with description below, matching AI model preference card style
    private var loopIntegrationCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Main toggle box
            HStack(spacing: 14) {
                // Text content on the left - same font as other rows
                Text("Show Loop integration")
                    .font(.body)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Toggle switch on the right
                // Rule: General Coding - Use native Toggle for Apple design consistency
                Toggle("", isOn: $showLoopIntegration)
                    .labelsHidden()
                    .onChange(of: showLoopIntegration) { _, newValue in
                        print("[PlanView] Loop integration toggled to: \(newValue)")
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6))
            )
            
            // Description text below the box
            Text("With this feature on, you can open the loop app from the results page. Only works if you have loop installed to your iPhone")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 15)
        }
    }
    
    // MARK: - Loading View
    
    /// Loading indicator shown while Firebase is initializing
    /// Rule: General Coding - Provide clear feedback during async operations, simplified with no border
    /// This prevents showing empty state while data is being fetched
    private var loadingView: some View {
        HStack(spacing: 12) {
            // Native iOS loading spinner
            ProgressView()
                .progressViewStyle(.circular)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Loading plan details...")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Text("Connecting to server")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6))
        )
    }
}

// MARK: - Safari View Wrapper

/// SwiftUI wrapper for SFSafariViewController
/// Rule: General Coding - Use native Safari Services for in-app web browsing
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        config.barCollapsingEnabled = true
        
        let safari = SFSafariViewController(url: url, configuration: config)
        safari.preferredControlTintColor = .systemBlue
        
        print("[SafariView] Opening URL: \(url.absoluteString)")
        return safari
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - Preview

#Preview {
    // Rule: State Management - Create dependencies for preview
    PlanView()
        .environmentObject(UserInstallationManager())
        .environmentObject(SubscriptionManager())
        .environmentObject(CaptureUsageManager())
}
