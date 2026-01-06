//
//  PromoBoxManager.swift
//  CarbFinder
//
//  Manages promotional box configuration from Firebase Remote Config
//  Rule: General Coding - Simple singleton pattern for easy access across app
//  Rule: State Management - Uses @Published for SwiftUI reactivity

import Foundation
import FirebaseRemoteConfig
import Combine

/// Configuration data for the promotional box
/// Rule: General Coding - Separate data model for clean architecture
struct PromoBoxConfig {
    /// Whether to show the app logo or an SF Symbol
    enum IconType {
        case appLogo
        case sfSymbol(String)
    }
    
    let iconType: IconType
    let title: String
    let subtitle: String
    let linkURL: String? // Optional URL to open in web viewer when box is tapped
    let enableShare: Bool // Whether to show share sheet instead of opening link
    let shareText: String? // Text to share when share is enabled
    let isEnabled: Bool // Whether the promo box should be shown at all
    
    /// Default configuration (fallback if Firebase fetch fails)
    /// Rule: General Coding - Always have a working fallback
    static let `default` = PromoBoxConfig(
        iconType: .appLogo,
        title: "Welcome back to Carbetic",
        subtitle: "Keep tracking your carbs with ease",
        linkURL: nil, // No link by default
        enableShare: false, // Share disabled by default
        shareText: nil, // No share text by default
        isEnabled: false // Disabled by default until configured in Firebase
    )
}

/// Manages promotional box configuration from Firebase Remote Config
/// This allows updating the promo box content without requiring an app update
/// Rule: State Management - ObservableObject for SwiftUI reactivity
final class PromoBoxManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = PromoBoxManager()
    
    // MARK: - Published Properties
    
    /// The current promotional box configuration
    /// Rule: State Management - @Published for automatic SwiftUI updates
    @Published private(set) var config: PromoBoxConfig = .default
    
    // MARK: - Private Properties
    
    /// Firebase Remote Config instance
    private let remoteConfig: RemoteConfig
    
    /// Firebase Remote Config keys
    private let enabledKey = "promo_box_enabled"
    private let iconTypeKey = "promo_box_icon_type"
    private let iconValueKey = "promo_box_icon_value"
    private let titleKey = "promo_box_title"
    private let subtitleKey = "promo_box_subtitle"
    private let linkURLKey = "promo_box_link_url"
    private let enableShareKey = "promo_box_enable_share"
    private let shareTextKey = "promo_box_share_text"
    
    // MARK: - Initialization
    
    private init() {
        print("[PromoBox] Initializing PromoBoxManager") // Rule: General Coding - Add debug logs
        
        // Initialize Firebase Remote Config
        remoteConfig = RemoteConfig.remoteConfig()
        
        // Configure settings: fetch interval and timeout
        // Rule: Performance Optimization - Reasonable fetch interval to avoid excessive network calls
        let settings = RemoteConfigSettings()
        
        // Rule: General Coding - Use 0 interval in DEBUG mode for immediate fetches during development
        // In production, use 1-hour interval to reduce network calls
        #if DEBUG
        settings.minimumFetchInterval = 0 // DEBUG: Always fetch latest (no cache)
        print("[PromoBox] 🔧 DEBUG MODE: Fetch interval set to 0 (always fetch fresh)")
        #else
        settings.minimumFetchInterval = 3600 // PRODUCTION: Fetch at most once per hour
        #endif
        
        settings.fetchTimeout = 10 // Timeout after 10 seconds if network is slow
        remoteConfig.configSettings = settings
        
        // Set default values (used if Firebase fetch fails or hasn't happened yet)
        // Rule: General Coding - Always have a working fallback
        remoteConfig.setDefaults([
            enabledKey: false as NSObject,
            iconTypeKey: "logo" as NSObject, // "logo" or "symbol"
            iconValueKey: "" as NSObject, // SF Symbol name (only used if iconType is "symbol")
            titleKey: "Welcome back to Carbetic" as NSObject,
            subtitleKey: "Keep tracking your carbs with ease" as NSObject,
            linkURLKey: "" as NSObject, // Optional URL to open when box is tapped
            enableShareKey: false as NSObject, // Share functionality disabled by default
            shareTextKey: "" as NSObject // Text to share (only used if enableShare is true)
        ])
        
        print("[PromoBox] Remote Config initialized with defaults")
    }
    
    // MARK: - Public Methods
    
    /// Fetches the latest promotional box configuration from Firebase Remote Config
    /// Call this when the app starts (e.g., in your App init or ContentView.onAppear)
    /// Rule: Swift Concurrency - Uses async/await for clean code
    func fetchConfiguration() async {
        print("[PromoBox] Starting Remote Config fetch...")
        
        do {
            // Fetch and activate in one call
            // Rule: General Coding - fetchAndActivate combines fetch + activate for simplicity
            let status = try await remoteConfig.fetchAndActivate()
            
            switch status {
            case .successFetchedFromRemote:
                print("[PromoBox] ✅ Successfully fetched NEW config from Firebase")
            case .successUsingPreFetchedData:
                print("[PromoBox] ✅ Using previously fetched config (still fresh)")
            case .error:
                print("[PromoBox] ⚠️ Fetch succeeded but activation had an error")
            @unknown default:
                print("[PromoBox] ⚠️ Unknown fetch status: \(status)")
            }
            
            // Parse configuration from Remote Config
            let isEnabled = remoteConfig.configValue(forKey: enabledKey).boolValue
            let title = remoteConfig.configValue(forKey: titleKey).stringValue ?? "Welcome back to Carbetic"
            let subtitle = remoteConfig.configValue(forKey: subtitleKey).stringValue ?? "Keep tracking your carbs with ease"
            let iconTypeString = remoteConfig.configValue(forKey: iconTypeKey).stringValue ?? "logo"
            let iconValue = remoteConfig.configValue(forKey: iconValueKey).stringValue ?? ""
            let linkURLString = remoteConfig.configValue(forKey: linkURLKey).stringValue ?? ""
            let enableShare = remoteConfig.configValue(forKey: enableShareKey).boolValue
            let shareTextString = remoteConfig.configValue(forKey: shareTextKey).stringValue ?? ""
            
            // Determine icon type
            let iconType: PromoBoxConfig.IconType
            if iconTypeString == "symbol" && !iconValue.isEmpty {
                iconType = .sfSymbol(iconValue)
                print("[PromoBox] Icon: SF Symbol '\(iconValue)'")
            } else {
                iconType = .appLogo
                print("[PromoBox] Icon: App Logo")
            }
            
            // Parse link URL (optional)
            let linkURL: String? = linkURLString.isEmpty ? nil : linkURLString
            if let url = linkURL {
                print("[PromoBox] Link URL: \(url)")
            } else {
                print("[PromoBox] No link URL configured")
            }
            
            // Parse share text (optional)
            let shareText: String? = shareTextString.isEmpty ? nil : shareTextString
            if enableShare {
                print("[PromoBox] Share enabled: true")
                if let text = shareText {
                    print("[PromoBox] Share text: \(text)")
                } else {
                    print("[PromoBox] ⚠️ Share enabled but no share text provided")
                }
            } else {
                print("[PromoBox] Share enabled: false")
            }
            
            // Update configuration on main thread
            // Rule: Swift Concurrency - UI updates must be on main thread
            await MainActor.run {
                config = PromoBoxConfig(
                    iconType: iconType,
                    title: title,
                    subtitle: subtitle,
                    linkURL: linkURL,
                    enableShare: enableShare,
                    shareText: shareText,
                    isEnabled: isEnabled
                )
                print("[PromoBox] ✅ Configuration updated - enabled: \(isEnabled)")
                print("[PromoBox] Title: \(title)")
                print("[PromoBox] Subtitle: \(subtitle)")
            }
            
        } catch {
            // If fetch fails, we keep using the default value
            // Rule: General Coding - Graceful degradation on network failure
            print("[PromoBox] ⚠️ Failed to fetch Remote Config: \(error.localizedDescription)")
            print("[PromoBox] Continuing with default configuration")
        }
    }
    
    // MARK: - Testing/Preview Support
    
    /// Updates the configuration manually (for testing and previews only)
    /// Rule: General Coding - Provide testing hooks for Xcode previews
    /// - Parameter newConfig: The configuration to apply
    @MainActor
    func setConfigForPreview(_ newConfig: PromoBoxConfig) {
        config = newConfig
        print("[PromoBox] ⚙️ Configuration manually set for preview/testing")
    }
}
