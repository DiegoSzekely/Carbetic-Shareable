//
//  WelcomeView.swift
//  CarbFinder
//
//  Created by Diego Szekely on 19.11.25.
// This is the view presented to the user when first opening the app for the first time

import SwiftUI
import SafariServices

struct WelcomeView: View {
    // Callback for when the user completes onboarding
    var onComplete: () -> Void
    
    // Rule: State Management - Access installation manager to start initialization during welcome
    @EnvironmentObject var installationManager: UserInstallationManager
    
    // Define the accent color to match your button
    private let accentColor = Color.blue
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer()
                
                
                // Main title with animated word
                AnimatedTaglineView(animateWords: true)
                    .padding(.horizontal, 25)
                
                Text("Get back to eating what you love \(Image(systemName: "heart.fill"))")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 25)
                    .padding(.top, 50)
                
                Spacer()
                Spacer()
                
                // Get Started button
                Button(action: {
                    // Rule: Visual Design - Soft haptic feedback for gentle user experience
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    
                    // Call completion handler to navigate to ContentView
                    onComplete()
                }) {
                    Text("Get Started")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(accentColor)
                        .cornerRadius(14)
                }
                .padding(.horizontal, 25)
                .padding(.bottom, 10)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .onAppear {
                // Rule: State Management - Start initialization in background during welcome screen
                // This ensures initialization is complete by the time user taps "Get Started"
                print("[WelcomeView] Starting background initialization for first-time user")
                AppInitializationManager.shared.startInitialization(installationManager: installationManager)
            }
        }
    }
}

#Preview {
    WelcomeView(onComplete: {
        print("Onboarding completed")
    })
    .environmentObject(UserInstallationManager())
}

