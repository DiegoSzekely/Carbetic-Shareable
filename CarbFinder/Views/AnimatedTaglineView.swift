//
//  AnimatedTaglineView.swift
//  CarbFinder
//
//  Created by AI Assistant on 24.11.25.
//

import SwiftUI

/// Reusable animated tagline component showing "Carb counting should be [quick/precise/easy.]"
/// Rule: SwiftUI-specific Patterns - Extract reusable components into separate views
struct AnimatedTaglineView: View {
    
    // MARK: - Properties
    
    /// Whether to show the full animation cycle or stick with the final word
    let animateWords: Bool
    
    /// Text color for the tagline
    let textColor: Color
    
    /// Accent color for the animated word
    let accentColor: Color
    
    /// Whether to enable haptic feedback on word changes
    let enableHaptics: Bool
    
    /// Whether to enable shimmer effect on final word
    let enableShimmer: Bool
    
    /// State to track the current word in the animation
    @State private var currentWordIndex: Int
    
    /// The words that will cycle through
    private let words = ["quick", "precise", "easy."]
    
    /// Timer for word rotation
    @State private var wordTimer: Timer?
    
    /// Shimmer effect for the final word
    @State private var shimmerOffset: CGFloat = -250
    
    // MARK: - Initialization
    
    /// Initialize the animated tagline view
    /// - Parameters:
    ///   - animateWords: If true, cycles through all words once. If false, starts and stays on "easy."
    ///   - textColor: Color for the main text (default: .primary)
    ///   - accentColor: Color for the animated word (default: .blue)
    ///   - enableHaptics: Whether to enable haptic feedback on word changes (default: true)
    ///   - enableShimmer: Whether to enable shimmer effect on final word (default: true)
    init(animateWords: Bool = true, textColor: Color = .primary, accentColor: Color = .blue, enableHaptics: Bool = true, enableShimmer: Bool = true) {
        self.animateWords = animateWords
        self.textColor = textColor
        self.accentColor = accentColor
        self.enableHaptics = enableHaptics
        self.enableShimmer = enableShimmer
        // If not animating, start with the final word
        self._currentWordIndex = State(initialValue: animateWords ? 0 : 2)
    }
    
    // MARK: - Body
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Carb counting")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
            
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("should be")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(textColor)
                
                // Animated word with overlay to prevent layout shifts
                ZStack(alignment: .leading) {
                    // Actual animated text
                    Text(words[currentWordIndex])
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundColor(accentColor)
                        .overlay(
                            // Shimmer effect for the last word (only if enabled and in light mode)
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            .clear,
                                            .white.opacity(0.6),
                                            .white.opacity(0.8),
                                            .white.opacity(0.6),
                                            .clear
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 120)
                                .offset(x: shimmerOffset)
                                .opacity(currentWordIndex == words.count - 1 && enableShimmer && colorScheme == .light ? 1 : 0)
                                .blendMode(.overlay)
                        )
                        .id("animatedWord-\(currentWordIndex)")
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.9)),
                            removal: .opacity.combined(with: .scale(scale: 0.9))
                        ))
                }
                
                Spacer()
            }
            .padding(.top, 4)
        }
        .onAppear {
            if animateWords {
                // Start the timer when the view appears
                startWordRotation()
            } else if enableShimmer && colorScheme == .light {
                // Just trigger the shimmer effect once for the final word (if enabled and in light mode)
                triggerShimmer()
            }
        }
        .onDisappear {
            // Clean up the timer when the view disappears
            wordTimer?.invalidate()
        }
    }
    
    // MARK: - Private Methods
    
    /// Function to handle word rotation with haptic feedback - cycles once through all words
    private func startWordRotation() {
        // Rule: Performance Optimization - Reduced from 3.0 to 2.1 seconds (30% faster)
        wordTimer = Timer.scheduledTimer(withTimeInterval: 2.1, repeats: true) { timer in
            // Only animate if we haven't reached the last word
            guard currentWordIndex < words.count - 1 else {
                // Stop the timer once we reach "easy."
                timer.invalidate()
                return
            }
            
            withAnimation(.easeInOut(duration: 0.5)) {
                currentWordIndex += 1
            }
            
            // Trigger haptic feedback on word change (only if enabled)
            if enableHaptics {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
            
            // Trigger shimmer effect when reaching the last word (only if enabled and in light mode)
            if currentWordIndex == words.count - 1 && enableShimmer && colorScheme == .light {
                triggerShimmer()
            }
        }
    }
    
    /// Trigger the shimmer animation
    private func triggerShimmer() {
        // Reset shimmer position
        shimmerOffset = -250
        // Animate shimmer across the text
        withAnimation(.easeOut(duration: 2.0).delay(0.5)) {
            shimmerOffset = 350
        }
    }
}

#Preview("Animating") {
    AnimatedTaglineView(animateWords: true)
        .padding()
}

#Preview("Static on 'easy.'") {
    AnimatedTaglineView(animateWords: false)
        .padding()
}
