//
//  AppInitializationManager.swift
//  CarbFinder
//
//  Created on 15.12.25.
//  Manages app initialization state to ensure smooth startup
//  Rules Applied: General Coding, State Management, Performance Optimization

import Foundation
import Combine

/// Manages the app initialization state
/// Tracks when Firebase and other critical services are ready
/// Ensures initialization screen shows for minimum duration (smooth UX)
/// Rule: State Management - ObservableObject for app-wide initialization tracking
@MainActor
final class AppInitializationManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Whether the app is ready to display main content
    /// Rule: State Management - @Published for SwiftUI reactivity
    @Published private(set) var isReady: Bool = false
    
    // MARK: - Private Properties
    
    /// Minimum time to show initialization screen (for smooth UX)
    /// Rule: Apple Design Guidelines - Don't flash loading screen too quickly
    private let minimumDisplayTime: TimeInterval = 1.5 // 1.5 seconds minimum
    
    /// Maximum time to wait for initialization before continuing anyway
    /// Rule: Error Handling - Don't block user forever if something fails
    private let maximumWaitTime: TimeInterval = 5.0 // 5 seconds maximum
    
    /// Time when initialization started
    private var startTime: Date?
    
    /// Whether Firebase/managers have finished loading
    private var servicesReady: Bool = false
    
    /// Whether minimum display time has elapsed
    private var minimumTimeElapsed: Bool = false
    
    /// Cancellable for monitoring installation manager
    private var cancellable: AnyCancellable?
    
    // MARK: - Singleton
    
    static let shared = AppInitializationManager()
    
    private init() {
        print("[AppInit] 🚀 Manager initialized")
    }
    
    // MARK: - Public Methods
    
    /// Starts tracking initialization
    /// Call this from ContentView.onAppear
    /// Rule: General Coding - Explicit start method for clarity
    func startInitialization(installationManager: UserInstallationManager) {
        guard startTime == nil else {
            print("[AppInit] ⚠️ Already started, ignoring")
            return
        }
        
        startTime = Date()
        print("[AppInit] ⏱️ Starting initialization tracking")
        
        // Start minimum time timer
        startMinimumTimeTimer()
        
        // Start maximum wait timer (failsafe)
        startMaximumWaitTimer()
        
        // Monitor installation manager's loading state
        monitorInstallationManager(installationManager)
    }
    
    // MARK: - Private Methods
    
    /// Starts timer for minimum display time
    /// Rule: Apple Design Guidelines - Smooth transitions, no flashing
    private func startMinimumTimeTimer() {
        Task {
            try? await Task.sleep(nanoseconds: UInt64(minimumDisplayTime * 1_000_000_000))
            print("[AppInit] ⏱️ Minimum time elapsed (\(minimumDisplayTime)s)")
            minimumTimeElapsed = true
            checkIfReady()
        }
    }
    
    /// Starts failsafe timer to continue even if services don't finish
    /// Rule: Error Handling - Don't block user indefinitely
    private func startMaximumWaitTimer() {
        Task {
            try? await Task.sleep(nanoseconds: UInt64(maximumWaitTime * 1_000_000_000))
            if !isReady {
                print("[AppInit] ⚠️ Maximum wait time reached (\(maximumWaitTime)s), continuing anyway")
                servicesReady = true
                minimumTimeElapsed = true
                checkIfReady()
            }
        }
    }
    
    /// Monitors the installation manager's loading state
    /// Rule: State Management - Combine for reactive state observation
    private func monitorInstallationManager(_ installationManager: UserInstallationManager) {
        // Check initial state
        if !installationManager.isLoading {
            print("[AppInit] ✅ Installation manager already ready")
            servicesReady = true
            checkIfReady()
            return
        }
        
        // Monitor changes
        cancellable = installationManager.$isLoading
            .sink { [weak self] isLoading in
                guard let self = self else { return }
                
                if !isLoading {
                    print("[AppInit] ✅ Installation manager finished loading")
                    Task { @MainActor in
                        self.servicesReady = true
                        self.checkIfReady()
                    }
                    self.cancellable?.cancel()
                }
            }
    }
    
    /// Checks if both conditions are met to mark app as ready
    /// Rule: General Coding - Single decision point for state transition
    private func checkIfReady() {
        guard !isReady else { return }
        
        if servicesReady && minimumTimeElapsed {
            if let start = startTime {
                let elapsed = Date().timeIntervalSince(start)
                print("[AppInit] ✅ App ready! (elapsed: \(String(format: "%.2f", elapsed))s)")
            }
            isReady = true
        } else {
            print("[AppInit] ⏳ Not ready yet - services: \(servicesReady), time: \(minimumTimeElapsed)")
        }
    }
}
