//
//  CarbFinderApp.swift
//  CarbFinder
//
//  Created by Diego Szekely on 14.10.25.
//

import SwiftUI
import FirebaseCore
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    
    // Rule: General Coding - Initialize AI model config manager to fetch from Firebase
    // This ensures the latest AI model configuration is available when app starts
    let _ = AIModelConfigManager.shared
    print("[Firebase] AI model configuration manager initialized")
    
    // Rule: General Coding - Initialize promo box config manager to fetch from Firebase
    // This ensures the latest promotional box configuration is available when app starts
    let _ = PromoBoxManager.shared
    print("[Firebase] Promo box configuration manager initialized")
    
    // Rule: General Coding - Suppress App Check warnings during development
    // App Check is optional and not needed for basic Auth/Firestore functionality
    #if DEBUG
    print("[Firebase] App Check warnings are expected in development mode")
    #endif
    
    // Rule: Push Notifications - Set notification delegate
    UNUserNotificationCenter.current().delegate = self
    print("[Notifications] Delegate set")
    
    // Rule: Push Notifications - DO NOT request permissions here
    // Permissions will be requested on 3rd capture attempt
    
    return true
  }
  
  // Rule: Push Notifications - Handle successful registration
  func application(_ application: UIApplication, 
                   didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
      let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
      print("[Notifications] 📱 Device token: \(token)")
  }
  
  // Rule: Push Notifications - Handle registration failure
  func application(_ application: UIApplication, 
                   didFailToRegisterForRemoteNotificationsWithError error: Error) {
      print("[Notifications] ❌ Failed to register: \(error)")
  }
  
  // Rule: Push Notifications - Handle notification when app is in foreground
  func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
      print("[Notifications] 📬 Received notification while in foreground")
      // Show notification even when app is open
      completionHandler([.banner, .sound, .badge])
  }
  
  // Rule: Push Notifications - Handle notification tap
  func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
      let userInfo = response.notification.request.content.userInfo
      print("[Notifications] 👆 User tapped notification: \(userInfo)")
      completionHandler()
  }
}

@main
struct CarbFinderApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // Rule: State Management - Track onboarding completion with @AppStorage for persistence
    // This persists across app launches and determines whether to show WelcomeView
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    // Rule: State Management - Create StateObject for app-wide history store
    // This ensures a single instance exists throughout the app lifecycle
    @StateObject private var historyStore = ScanHistoryStore()
    
    // Rule: State Management - Create StateObject for app-wide installation manager
    // This tracks installation date server-side to prevent trial bypass
    @StateObject private var installationManager = UserInstallationManager()
    
    // Rule: State Management - Create StateObject for subscription management
    // This monitors StoreKit subscription status
    @StateObject private var subscriptionManager = SubscriptionManager()
    
    // Rule: State Management - Create StateObject for capture usage tracking
    // This tracks daily capture usage and resets at midnight
    @StateObject private var usageManager = CaptureUsageManager()
    
    // Rule: State Management - Create StateObject for network connectivity monitoring
    // This monitors network status and blocks actions requiring internet when offline
    @StateObject private var networkMonitor = NetworkMonitor()
    
    // Rule: State Management - Create StateObject for promotional box manager
    // This manages dynamic promotional box content from Firebase Remote Config
    @StateObject private var promoBoxManager = PromoBoxManager.shared
    
    init() {
        // Rule: State Management - Connect subscription manager to usage manager
        // This allows subscription manager to reset usage on upgrade
        _subscriptionManager.wrappedValue.usageManager = _usageManager.wrappedValue
    }
    
    var body: some Scene {
        WindowGroup {
            // Rule: General Coding - Conditionally show WelcomeView on first launch
            // Firebase initialization happens in background while user views welcome screen
            if hasCompletedOnboarding {
                ContentView()
                    // Rule: State Management - Pass historyStore via environment for easy access
                    .environmentObject(historyStore)
                    // Rule: State Management - Pass installationManager via environment
                    .environmentObject(installationManager)
                    // Rule: State Management - Pass subscriptionManager via environment
                    .environmentObject(subscriptionManager)
                    // Rule: State Management - Pass usageManager via environment
                    .environmentObject(usageManager)
                    // Rule: State Management - Pass networkMonitor via environment
                    .environmentObject(networkMonitor)
                    // Rule: State Management - Pass promoBoxManager via environment
                    .environmentObject(promoBoxManager)
            } else {
                // Rule: General Coding - Show WelcomeView on first launch
                // User sees welcome screen while Firebase initializes in background
                WelcomeView {
                    // Rule: General Coding - Mark onboarding complete when user taps "Get Started"
                    print("[Onboarding] User completed welcome screen, navigating to ContentView")
                    hasCompletedOnboarding = true
                }
                // Rule: State Management - Pass environment objects to WelcomeView
                // This ensures managers are initialized during welcome screen
                .environmentObject(historyStore)
                .environmentObject(installationManager)
                .environmentObject(subscriptionManager)
                .environmentObject(usageManager)
                .environmentObject(networkMonitor)
                .environmentObject(promoBoxManager)
            }
        }
    }
}
