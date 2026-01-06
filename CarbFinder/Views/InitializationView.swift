//
//  InitializationView.swift
//  CarbFinder
//
//  Created on 15.12.25.
//  Loading screen shown during app initialization (Firebase, etc.)
//  Rules Applied: General Coding, SwiftUI-specific Patterns, Apple Design Guidelines

import SwiftUI

/// Initialization view with animated logo and app name
/// Shows while Firebase and other managers initialize
/// Rule: General Coding - Separate initialization UI from main content for better UX
struct InitializationView: View {
    
    // MARK: - Animation State
    
    /// Controls the logo position and text reveal animation
    /// Rule: State Management - Use @State for view-local animation control
    @State private var animationPhase: AnimationPhase = .initial
    
    /// Phase of the animation
    private enum AnimationPhase {
        case initial      // Logo centered, text hidden behind
        case animating    // Logo moving left, text moving right (revealed)
        case final        // Logo left, text visible - final position
    }
    
    // MARK: - Animation Constants
    
    /// Logo size
    private let logoSize: CGFloat = 80
    
    /// Horizontal spacing between logo and text in final state
    private let logoTextSpacing: CGFloat = 12
    
    /// Animation duration for smooth transition
    private let animationDuration: Double = 1.0
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background color matches your app's light blue theme
            // Rule: Apple Design Guidelines - Use consistent color scheme
            Color(red: 0xE7/255.0, green: 0xF0/255.0, blue: 0xF2/255.0)
                .ignoresSafeArea()
            
            // Content
            GeometryReader { geometry in
                let screenWidth = geometry.size.width
                let screenHeight = geometry.size.height
                
                // Calculate final position (logo + spacing + text centered together)
                // First, calculate the total width of the final composition
                let textWidth = calculateTextWidth()
                let totalFinalWidth = logoSize + logoTextSpacing + textWidth
                
                // Center point for the final composition
                let finalCenterX = screenWidth / 2
                
                // Logo's final x position (left edge of composition + half logo width)
                let logoFinalX = finalCenterX - (totalFinalWidth / 2) + (logoSize / 2)
                
                // Text's final x position (right side of composition)
                let textFinalX = logoFinalX + logoSize / 2 + logoTextSpacing + textWidth / 2
                
                // Text's initial x position - start BEHIND and to the RIGHT of logo
                // This ensures text is fully hidden behind logo at start
                // Position it so the LEFT edge of text aligns with CENTER of logo
                let textInitialX = screenWidth / 2 + (textWidth / 2)
                
                ZStack {
                    // "Carbetic" text - BEHIND logo initially, fully hidden
                    // Rule: SwiftUI-specific Patterns - Z-order by declaration order (first = behind)
                    Text("Carbetic")
                        .font(.system(size: 40, weight: .bold, design: .default)) // Rule: Visual Design - Bold text as requested
                        .foregroundStyle(.black) // Rule: Visual Design - Black text as requested
                        .position(
                            x: animationPhase == .initial ? textInitialX : textFinalX,
                            y: screenHeight / 2
                        )
                        .animation(.spring(response: animationDuration, dampingFraction: 0.8), value: animationPhase)
                    
                    // Logo - ON TOP, moves left to reveal text behind it
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: logoSize, height: logoSize)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .position(
                            x: animationPhase == .initial ? screenWidth / 2 : logoFinalX,
                            y: screenHeight / 2
                        )
                        .animation(.spring(response: animationDuration, dampingFraction: 0.8), value: animationPhase)
                }
                .frame(width: screenWidth, height: screenHeight)
            }
        }
        .onAppear {
            // Start animation after a brief delay
            // Rule: Apple Design Guidelines - Brief pause before animation feels more polished
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    animationPhase = .animating
                }
            }
            
            // Complete animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1 + animationDuration) {
                withAnimation {
                    animationPhase = .final
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Calculates the width of the "Carbetic" text
    /// Rule: General Coding - Calculate text dimensions for proper positioning
    private func calculateTextWidth() -> CGFloat {
        let font = UIFont.systemFont(ofSize: 40, weight: .bold) // Updated to bold
        let attributes = [NSAttributedString.Key.font: font]
        let size = ("Carbetic" as NSString).size(withAttributes: attributes)
        return size.width
    }
}

// MARK: - Preview

#Preview("Initialization View") {
    InitializationView()
}
