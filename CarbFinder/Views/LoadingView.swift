//
//  LoadingView.swift
//  CarbFinder
//
//  Created on 11.11.25.
//  Simple loading screen
//  Rules Applied: General Coding, SwiftUI-specific Patterns, Apple Design Guidelines

import SwiftUI
#if canImport(DotLottie)
import DotLottie
#endif

/// Loading view with simple visual indicator
/// Rule: General Coding - Separate loading UI from result UI for better UX
struct LoadingView: View {
    @Environment(\.colorScheme) private var colorScheme // Rule: State Management - Use Environment for system-wide settings
    @Environment(\.scenePhase) private var scenePhase // Rule: SwiftUI Lifecycle - Monitor app lifecycle
    @Binding var aiCompleted: Bool // Binding to show success state when AI completes
    
    // Type of scan to determine which messages to show
    // Rule: State Management - Pass scan type to customize UI
    enum ScanType {
        case meal      // Three-photo meal analysis
        case recipe    // Single-photo or URL recipe analysis
    }
    let scanType: ScanType

    // Lottie animation file name (without .json). Update this to your file name.
    private let lottieAnimationName: String = "loading"
    // Background adapts to color scheme: pure black in dark mode, system gray in light mode
    // Rule: Apple Design Guidelines - Optimize for dark mode; General Coding - Simple conditional
    private var backgroundColor: Color {
        if colorScheme == .dark {
            return .black
        } else {
            return Color(UIColor.systemGray6)
        }
    }
    
    // MARK: - MANDATORY DISCLAIMER - COMMENTED OUT - START
    // Disclaimer acceptance state
    // Rule: State Management - Track disclaimer acceptance device-wide
    // @AppStorage(UserDefaults.disclaimerAcceptedKey) private var hasAcceptedDisclaimer: Bool = false
    
    // State for disclaimer sheet presentation
    // Rule: State Management - Control sheet presentation
    // @State private var showingDisclaimerSheet: Bool = false
    // @State private var userAcceptedDisclaimer: Bool = false // Tracks if user accepted in this session
    // MARK: - MANDATORY DISCLAIMER - COMMENTED OUT - END
    
    // State for success indicator
    // Rule: State Management - Use @State for local view state
    @State private var isSuccess: Bool = false // Controls white -> green transition
    
    // State for Lottie animation playback
    // Rule: SwiftUI-specific Patterns - Use @State for animation control
    @State private var isAnimating: Bool = false // Controls Lottie playback
    
    // State for status messages
    // Rule: State Management - Use @State for message cycling
    @State private var currentMessageIndex: Int = 0 // Which message to display
    @State private var messageOpacity: Double = 0.0 // Controls fade in/out
    @State private var loadingTextOpacity: Double = 0.0 // Controls "Analyzing..." text fade
    
    // State for haptic feedback control
    // Rule: General Coding - Pause haptics when disclaimer sheet is open
    // MARK: - MANDATORY DISCLAIMER - COMMENTED OUT - START
    // @State private var hapticsEnabled: Bool = true
    // MARK: - MANDATORY DISCLAIMER - COMMENTED OUT - END
    
    // State for timeout detection
    // Rule: Error Handling - Detect if loading takes too long (stuck request)
    @State private var loadingStartTime: Date? = nil
    
    // Haptic feedback generators
    // Rule: Apple Design Guidelines - Use haptics to enhance user experience
    private let impactFeedback = UIImpactFeedbackGenerator(style: .soft) // Softer, more subtle feedback
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    // Messages based on scan type
    // Rule: General Coding - Separate data from presentation
    private var messages: [String] {
        switch scanType {
        case .meal:
            return [
                "Analyzing the individual food components...",
                "Combining the three perspectives to estimate volumes and weights...",
                "Researching nutritional information for each component...",
                "Calculating total carb content..."
            ]
        case .recipe:
            return [
                "Extracting the recipe...",
                "Researching nutritional information for each ingredient...",
                "Calculating net carbs in each ingredient...",
                "Combining the net carbs in each ingredient..."
            ]
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background color - system gray
                // Rule: Apple Design Guidelines - Use system colors for adaptive light/dark mode
                backgroundColor
                    // Uses pure black in dark mode, system gray in light mode
                    .ignoresSafeArea()
                
                let screenWidth = geometry.size.width
                let screenHeight = geometry.size.height
                
                // Lottie animation diameter = 60% of the screen width
                // Rule: General Coding - Maintain consistent sizing
                let animationSize = screenWidth * 0.6
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    // DotLottieAnimation View replacing LottieView
                    if !isSuccess {
                        LoadingAnimation(fileName: lottieAnimationName, size: animationSize)
                            .accessibilityLabel("Analyzing your meal")
                            .padding(.bottom, -8)
                    }
                    
                    // Animated "Analyzing..." text beneath Lottie
                    // Rule: SwiftUI-specific Patterns - Match WelcomeView animation style
                    LoadingAnimatedText(scanType: scanType)
                        .padding(.top, 0)
                        .opacity(loadingTextOpacity)
                        .opacity(isSuccess ? 0 : 1) // Hide on success
                    
                    Spacer()
                    
                    // Status message at the bottom with fixed height to prevent layout shifts
                    // Rule: General Coding - Fixed height container prevents other elements from moving
                    VStack(spacing: 0) {
                        Text("Keep the app open during analysis")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                            .accessibilityLabel("This may take up to 30 seconds - depending on your internet speed")
                    }
                    .frame(height: 60) // Fixed height for up to 3 lines of text
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 10)
                    .ignoresSafeArea(edges: .bottom)
                }
                .frame(width: screenWidth, height: screenHeight)
            }
        }
        .navigationBarHidden(true) // Rule: General Coding - No nav bar during loading
        .statusBarHidden(true) // Rule: Apple Design Guidelines - Immersive loading experience
        // MARK: - MANDATORY DISCLAIMER - COMMENTED OUT - START
        // .sheet(isPresented: $showingDisclaimerSheet) {
        //     // Rule: SwiftUI-specific Patterns - Present disclaimer sheet when needed
        //     DisclaimerView(onAccept: {
        //         print("[LoadingView] User accepted disclaimer in sheet")
        //         
        //         // Mark as accepted locally and in session
        //         hasAcceptedDisclaimer = true
        //         userAcceptedDisclaimer = true
        //         
        //         // Dismiss the sheet
        //         showingDisclaimerSheet = false
        //         
        //         // Resume haptics
        //         hapticsEnabled = true
        //         print("[LoadingView] Haptics resumed after disclaimer acceptance")
        //         
        //         // Record acceptance to Firestore (don't await, happens in background)
        //         Task {
        //             await DisclaimerManager.shared.recordAcceptance()
        //         }
        //         
        //         // Check if AI already completed while user was reading
        //         if aiCompleted {
        //             print("[LoadingView] AI already completed, showing success state")
        //             isAnimating = false
        //             notificationFeedback.notificationOccurred(.success)
        //             withAnimation(.easeInOut(duration: 0.2)) {
        //                 isSuccess = true
        //             }
        //         }
        //     })
        //     .interactiveDismissDisabled(true) // Prevent dismissal by swipe
        // }
        // MARK: - MANDATORY DISCLAIMER - COMMENTED OUT - END
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            
            // Rule: State Management - Track when loading started for timeout detection
            loadingStartTime = Date()
            
            print("[LoadingView] Appeared. Waiting for AI completion...")
            print("[LoadingView] Scan type: \(scanType)")
            let scheme = colorScheme == .dark ? "dark" : "light"
            let bgDesc = colorScheme == .dark ? "pure black" : "systemGray6"
            print("[LoadingView] Color scheme: \(scheme). Using background: \(bgDesc)")
            
            // MARK: - MANDATORY DISCLAIMER - COMMENTED OUT - START
            // Check if disclaimer needs to be shown
            // if !hasAcceptedDisclaimer {
            //     print("[LoadingView] Disclaimer not accepted, showing sheet")
            //     showingDisclaimerSheet = true
            //     hapticsEnabled = false // Pause haptics while sheet is open
            //     print("[LoadingView] Haptics paused while disclaimer sheet is open")
            // } else {
            //     print("[LoadingView] Disclaimer already accepted, proceeding normally")
            //     userAcceptedDisclaimer = true // Mark as accepted for this session
            //     
            //     // Rule: State Management - Check if AI already completed before view appeared
            //     // This handles the case where the request completed while app was backgrounded
            //     if aiCompleted {
            //         print("[LoadingView] AI already completed on appear, showing success state immediately")
            //         isAnimating = false
            //         notificationFeedback.notificationOccurred(.success)
            //         withAnimation(.easeInOut(duration: 0.2)) {
            //             isSuccess = true
            //         }
            //         return // Don't start animations
            //     }
            // }
            // MARK: - MANDATORY DISCLAIMER - COMMENTED OUT - END
            
            // Rule: State Management - Check if AI already completed before view appeared
            // This handles the case where the request completed while app was backgrounded
            if aiCompleted {
                print("[LoadingView] AI already completed on appear, showing success state immediately")
                isAnimating = false
                notificationFeedback.notificationOccurred(.success)
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSuccess = true
                }
                return // Don't start animations
            }
            
            // Prepare haptic generators
            // Rule: Performance Optimization - Prepare generators for lower latency
            impactFeedback.prepare()
            notificationFeedback.prepare()
            
            // MARK: - MANDATORY DISCLAIMER - COMMENTED OUT - START
            // Start animations only if disclaimer already accepted
            // Rule: SwiftUI-specific Patterns - Trigger animations in onAppear
            // if hasAcceptedDisclaimer {
            //     isAnimating = true
            //     print("[LoadingView] Lottie animation started")
            //     
            //     // Fade in the "Analyzing..." text
            //     withAnimation(.easeIn(duration: 0.5)) {
            //         loadingTextOpacity = 1.0
            //     }
            //     
            //     // Start haptic feedback pattern
            //     // Rule: Apple Design Guidelines - Subtle haptics enhance user experience
            //     startHapticPattern()
            //     
            //     // Start message cycling
            //     // Rule: General Coding - Separate concerns with dedicated method
            //     startMessageCycling()
            // }
            // MARK: - MANDATORY DISCLAIMER - COMMENTED OUT - END
            
            // Always start animations now that disclaimer is no longer mandatory
            isAnimating = true
            print("[LoadingView] Lottie animation started")
            
            // Fade in the "Analyzing..." text
            withAnimation(.easeIn(duration: 0.5)) {
                loadingTextOpacity = 1.0
            }
            
            // Start haptic feedback pattern
            // Rule: Apple Design Guidelines - Subtle haptics enhance user experience
            startHapticPattern()
            
            // Start message cycling
            // Rule: General Coding - Separate concerns with dedicated method
            startMessageCycling()
        }
        // MARK: - MANDATORY DISCLAIMER - COMMENTED OUT - START
        // .onChange(of: userAcceptedDisclaimer) { oldValue, newValue in
        //     // When user accepts disclaimer in sheet, start animations if not already started
        //     // Rule: SwiftUI-specific Patterns - Respond to state changes
        //     if newValue && !isAnimating && !isSuccess {
        //         print("[LoadingView] User accepted disclaimer, starting animations")
        //         isAnimating = true
        //         
        //         // Fade in the "Analyzing..." text
        //         withAnimation(.easeIn(duration: 0.5)) {
        //             loadingTextOpacity = 1.0
        //         }
        //         
        //         startHapticPattern()
        //         startMessageCycling()
        //     }
        // }
        // MARK: - MANDATORY DISCLAIMER - COMMENTED OUT - END
        .onChange(of: aiCompleted) { oldValue, newValue in
            // When AI completes, show success state
            // Rule: SwiftUI-specific Patterns - onChange for responding to binding changes
            if newValue == true {
                print("[LoadingView] AI response received.")
                
                // MARK: - MANDATORY DISCLAIMER - COMMENTED OUT - START
                // If disclaimer not accepted yet, wait for user to accept
                // if !userAcceptedDisclaimer {
                //     print("[LoadingView] Waiting for user to accept disclaimer before showing success")
                //     return
                // }
                // MARK: - MANDATORY DISCLAIMER - COMMENTED OUT - END
                
                print("[LoadingView] Showing success state...")
                
                // Stop animation and trigger success haptic
                // Rule: Apple Design Guidelines - Success haptic confirms completion
                isAnimating = false
                // MARK: - MANDATORY DISCLAIMER - COMMENTED OUT - START
                // if hapticsEnabled {
                //     notificationFeedback.notificationOccurred(.success)
                //     print("[LoadingView] Success haptic triggered")
                // }
                // MARK: - MANDATORY DISCLAIMER - COMMENTED OUT - END
                notificationFeedback.notificationOccurred(.success)
                print("[LoadingView] Success haptic triggered")
                
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSuccess = true
                }
                
                print("[LoadingView] Success state shown. Parent will handle navigation.")
            }
        }
        .onDisappear {
            print("[LoadingView] Disappeared")
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Rule: SwiftUI Lifecycle - Monitor scene phase to detect when app returns from background
            if newPhase == .active && oldPhase == .background {
                print("[LoadingView] 🔄 App returned to foreground")
                print("[LoadingView] Current state - aiCompleted: \(aiCompleted), isAnalyzing: \(AnalysisNotificationManager.shared.isAnalyzing)")
                
                // Rule: Error Handling - Check if loading has been stuck for too long
                if let startTime = loadingStartTime, !aiCompleted {
                    let elapsed = Date().timeIntervalSince(startTime)
                    print("[LoadingView] ⏱️ Time elapsed since loading started: \(String(format: "%.1f", elapsed))s")
                    
                    // Rule: Error Handling - If loading for more than 150 seconds (2.5 minutes), something is wrong
                    // The parent view (Capture3View) should handle this, but this is a backup check
                    if elapsed > 150 {
                        print("[LoadingView] ⚠️ Loading timeout detected (>150s) - parent view should handle error")
                    }
                }
                
                // If AI completed while backgrounded, the parent view's navigation should trigger
                // But we can force a UI update here
                if aiCompleted {
                    print("[LoadingView] AI was completed - parent should handle navigation")
                }
            }
        }
    }
    
    // MARK: - Haptic Feedback
    
    /// Starts the haptic feedback pattern: single gentle pulse every 4 seconds
    /// Rule: Apple Design Guidelines - Sync haptics with visual feedback
    private func startHapticPattern() {
        Task {
            // Continue pattern while view is in loading state
            while !isSuccess {
                // Single gentle tap at scale peak (2 seconds into 4-second cycle)
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds (peak of animation)
                if !isSuccess {
                    // MARK: - MANDATORY DISCLAIMER - COMMENTED OUT - START
                    // if !isSuccess && hapticsEnabled {
                    //     impactFeedback.impactOccurred()
                    //     print("[LoadingView] Haptic pulse")
                    // }
                    // MARK: - MANDATORY DISCLAIMER - COMMENTED OUT - END
                    impactFeedback.impactOccurred()
                    print("[LoadingView] Haptic pulse")
                }
                
                // Wait for rest of cycle (2 more seconds)
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            }
            print("[LoadingView] Haptic pattern stopped")
        }
    }
    
    // MARK: - Message Cycling
    
    /// Cycles through status messages with fade transitions synced to animation
    /// Rule: SwiftUI-specific Patterns - Smooth fade in/out animations synced with pulsation
    private func startMessageCycling() {
        Task { @MainActor in
            // Wait for first animation cycle to reach peak (2 seconds)
            // Rule: Apple Design Guidelines - Sync message changes with visual feedback
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds to first peak
            
            guard !isSuccess else {
                print("[LoadingView] AI completed before first message, skipping")
                return
            }
            
            // Cycle through messages - each change happens at animation peak
            // Each message now stays for 2 full cycles (8 seconds) instead of 1 cycle (4 seconds)
            for index in 0..<messages.count {
                guard !isSuccess else {
                    print("[LoadingView] AI completed at message \(index), stopping message cycle")
                    break
                }
                
                currentMessageIndex = index
                print("[LoadingView] Showing message \(index + 1)/\(messages.count): \(messages[index])")
                
                // Fade in quickly at peak (0.3s for crisp transition)
                withAnimation(.easeIn(duration: 0.3)) {
                    messageOpacity = 1.0
                }
                
                guard !isSuccess else {
                    print("[LoadingView] AI completed during message display, stopping")
                    break
                }
                
                // If this is the last message, keep it visible
                if index == messages.count - 1 {
                    print("[LoadingView] Last message reached, keeping visible until completion")
                    break
                }
                
                // Wait for 2 full animation cycles (8 seconds total) before next message
                // 7.7s visible + 0.3s fade out = 8s total, perfectly synced with 2 animation cycles
                try? await Task.sleep(nanoseconds: 7_700_000_000) // 7.7 seconds
                
                guard !isSuccess else {
                    print("[LoadingView] AI completed, stopping message cycle")
                    break
                }
                
                // Quick fade out just before next peak - 0.3s for smooth transition
                withAnimation(.easeOut(duration: 0.3)) {
                    messageOpacity = 0.0
                }
                
                // Wait for fade out to complete, then next loop will show new message at next peak
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            }
        }
    }
}

// MARK: - Loading Animation Wrapper (DotLottie or fallback)
private struct LoadingAnimation: View {
    let fileName: String
    let size: CGFloat
    var body: some View {
        Group {
            #if canImport(DotLottie)
            DotLottieAnimation(fileName: fileName, config: AnimationConfig(autoplay: true, loop: true)).view()
                .frame(width: size, height: size)
            #else
            // Fallback while DotLottie package is not added to the project
            ProgressView()
                .scaleEffect(1.2)
                .frame(width: size, height: size)
            #endif
        }
    }
}

// MARK: - Preview

#Preview("Loading State - Meal") {
    @Previewable @State var aiCompleted = false
    
    LoadingView(aiCompleted: $aiCompleted, scanType: .meal)
}

#Preview("Loading State - Recipe") {
    @Previewable @State var aiCompleted = false
    
    LoadingView(aiCompleted: $aiCompleted, scanType: .recipe)
}

#Preview("Success State - Meal") {
    @Previewable @State var aiCompleted = true
    
    LoadingView(aiCompleted: $aiCompleted, scanType: .meal)
}

// MARK: - Loading Animated Text Component

/// Animated text view that cycles through words with fade/scale transitions
/// Styled to match the AnimatedTaglineView's insertion/removal transitions
struct LoadingAnimatedText: View {
    let scanType: LoadingView.ScanType
    
    // Words to cycle through (displayed after the word "Analyzing")
    private var words: [String] {
        switch scanType {
        case .meal:
            return ["your images", "all perpectives", "approx. weight", "carbohydrates"]
        case .recipe:
            return ["your recipe", "ingredients", "carbohydrates"]
        }
    }

    // Current word index
    @State private var currentWordIndex: Int = 0

    // Timer driving the rotation
    @State private var wordTimer: Timer?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("Analyzing")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.primary)

            // Animated word with the same asymmetric transition used in AnimatedTaglineView
            ZStack(alignment: .leading) {
                Text(words[currentWordIndex])
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundColor(.blue) // Accent color
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .allowsTightening(true)
                    .id("loadingWord-\(currentWordIndex)")
                    .transition(
                        .asymmetric(
                            insertion: AnyTransition.opacity.combined(with: AnyTransition.scale(scale: 0.9)),
                            removal: AnyTransition.opacity.combined(with: AnyTransition.scale(scale: 0.9))
                        )
                    )
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading) // Expanded width and alignment
        }
        .padding(.leading, 70)
        .padding(.trailing, 8)
        .onAppear { startWordRotation() }
        .onDisappear {
            wordTimer?.invalidate()
            wordTimer = nil
        }
    }

    /// Rotate words every 3 seconds, using the same easeInOut timing as Welcome
    private func startWordRotation() {
        wordTimer?.invalidate()
        wordTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                currentWordIndex = (currentWordIndex + 1) % words.count
            }
        }
    }
}

// MARK: - Loading Animated Text Preview

#Preview("Loading Animated Text") {
    VStack {
        LoadingAnimatedText(scanType: .meal)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(UIColor.systemGray6))
}


