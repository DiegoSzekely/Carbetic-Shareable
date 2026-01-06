//
//  AnalysisNotificationManager.swift
//  CarbFinder
//
//  Manages local notifications for completed analyses when app is backgrounded
//  Rule: General Coding - Use local notifications for immediate feedback without server
//

import Foundation
import UserNotifications
import UIKit
import Combine

/// Manages notifications for analysis completion
/// Rule: State Management - ObservableObject allows SwiftUI views to react
@MainActor
class AnalysisNotificationManager: ObservableObject {
    /// Shared singleton instance
    static let shared = AnalysisNotificationManager()
    
    /// Track if app is currently in background
    @Published private(set) var isInBackground: Bool = false
    
    /// Track if an analysis is currently running
    @Published var isAnalyzing: Bool = false
    
    /// Track if permissions have been requested
    @Published private(set) var hasRequestedPermissions: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupBackgroundObserver()
        checkExistingPermissions()
    }
    
    /// Checks if notification permissions have already been granted
    /// Rule: General Coding - Check existing state to avoid redundant requests
    private func checkExistingPermissions() {
        Task { @MainActor in
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            if settings.authorizationStatus != .notDetermined {
                hasRequestedPermissions = true
                print("[AnalysisNotifications] Permissions already determined: \(settings.authorizationStatus.rawValue)")
            }
        }
    }
    
    /// Requests notification permissions from the user
    /// Rule: Push Notifications - Request permissions only when needed (6th capture)
    func requestPermissionsIfNeeded() {
        guard !hasRequestedPermissions else {
            print("[AnalysisNotifications] Permissions already requested, skipping")
            return
        }
        
        print("[AnalysisNotifications] 📱 Requesting notification permissions...")
        
        Task { @MainActor in
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                hasRequestedPermissions = true
                
                if granted {
                    print("[AnalysisNotifications] ✅ Permission granted")
                    // Register for remote notifications (for device token)
                    await UIApplication.shared.registerForRemoteNotifications()
                } else {
                    print("[AnalysisNotifications] ⚠️ Permission denied by user")
                }
            } catch {
                print("[AnalysisNotifications] ❌ Error requesting permissions: \(error)")
            }
        }
    }
    
    /// Sets up observers for app lifecycle events
    /// Rule: General Coding - Monitor app state to know when to send notifications
    private func setupBackgroundObserver() {
        // Observe when app goes to background
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.isInBackground = true
                    print("[AnalysisNotifications] 🌙 App entered background")
                }
            }
            .store(in: &cancellables)
        
        // Observe when app comes to foreground
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.isInBackground = false
                    print("[AnalysisNotifications] ☀️ App entered foreground")
                    // Cancel any pending notifications since user is back in app
                    self?.cancelPendingNotifications()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Sends a local notification when analysis completes while app is backgrounded
    /// Rule: Push Notifications - Use local notifications for immediate delivery
    func notifyAnalysisComplete(totalCarbs: Int, mealSummary: String) {
        // Only send notification if app is in background
        guard isInBackground else {
            print("[AnalysisNotifications] ℹ️ App in foreground, skipping notification")
            return
        }
        
        print("[AnalysisNotifications] 📤 Sending notification: \(totalCarbs)g carbs - \(mealSummary)")
        
        let content = UNMutableNotificationContent()
        content.title = "Analysis Complete! 🎉"
        content.body = "Your meal has ~\(totalCarbs)g net carbs"
        if !mealSummary.isEmpty {
            content.body += " · \(mealSummary)"
        }
        content.sound = .default
        content.badge = 1
        
        // Deliver immediately (no trigger = immediate delivery)
        let request = UNNotificationRequest(
            identifier: "analysis_complete",
            content: content,
            trigger: nil // nil trigger = deliver now
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[AnalysisNotifications] ❌ Error sending notification: \(error)")
            } else {
                print("[AnalysisNotifications] ✅ Notification sent successfully")
            }
        }
    }
    
    /// Sends a local notification when analysis fails due to no content detected
    /// Rule: Push Notifications - Notify user of content detection errors
    func notifyNoContent(errorMessage: String) {
        // Only send notification if app is in background
        guard isInBackground else {
            print("[AnalysisNotifications] ℹ️ App in foreground, skipping no-content notification")
            return
        }
        
        print("[AnalysisNotifications] 📤 Sending no-content notification: \(errorMessage)")
        
        let content = UNMutableNotificationContent()
        content.title = "Analysis was not completed"
        content.body = errorMessage
        content.sound = .default
        content.badge = 1
        
        // Deliver immediately (no trigger = immediate delivery)
        let request = UNNotificationRequest(
            identifier: "analysis_error",
            content: content,
            trigger: nil // nil trigger = deliver now
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[AnalysisNotifications] ❌ Error sending no-content notification: \(error)")
            } else {
                print("[AnalysisNotifications] ✅ No-content notification sent successfully")
            }
        }
    }
    
    /// Sends a local notification when analysis fails due to AI overload
    /// Rule: Push Notifications - Notify user of system overload errors
    func notifyAIOverload() {
        // Only send notification if app is in background
        guard isInBackground else {
            print("[AnalysisNotifications] ℹ️ App in foreground, skipping overload notification")
            return
        }
        
        print("[AnalysisNotifications] 📤 Sending AI overload notification")
        
        let content = UNMutableNotificationContent()
        content.title = "Analysis was not completed"
        content.body = "The system is overloaded. Try again."
        content.sound = .default
        content.badge = 1
        
        // Deliver immediately (no trigger = immediate delivery)
        let request = UNNotificationRequest(
            identifier: "analysis_error",
            content: content,
            trigger: nil // nil trigger = deliver now
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[AnalysisNotifications] ❌ Error sending overload notification: \(error)")
            } else {
                print("[AnalysisNotifications] ✅ Overload notification sent successfully")
            }
        }
    }
    
    /// Cancels any pending analysis notifications
    /// Rule: General Coding - Clean up notifications when no longer needed
    private func cancelPendingNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["analysis_complete"])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["analysis_complete"])
        print("[AnalysisNotifications] 🗑️ Cancelled pending notifications")
    }
    
    /// Resets the badge count
    /// Rule: Apple Design Guidelines - Keep badge count accurate
    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
}
