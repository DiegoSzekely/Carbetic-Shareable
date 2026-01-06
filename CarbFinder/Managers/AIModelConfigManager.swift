//
//  AIModelConfigManager.swift
//  CarbFinder
//
//  Manages AI model configuration from Firebase Remote Config
//  Rule: General Coding - Simple singleton pattern for easy access across app
//  Rule: State Management - Uses @Published for SwiftUI reactivity

import Foundation
import FirebaseRemoteConfig
import SwiftUI

/// User's preference for AI model speed vs accuracy
/// Rule: General Coding - Enum for type-safe model preference
enum AIModelPreference: String, Codable {
    case fast = "fast"
    case accurate = "accurate"
    
    var displayName: String {
        switch self {
        case .fast: return "Fast"
        case .accurate: return "Accurate"
        }
    }
    
    var description: String {
        switch self {
        case .fast: return "Quick responses for everyday use"
        case .accurate: return "More thorough analysis, takes longer"
        }
    }
}

/// Manages which AI model to use by fetching configuration from Firebase Remote Config
/// This allows updating the AI model without requiring an app update
/// Rule: State Management - Observable class for SwiftUI reactivity
@Observable
final class AIModelConfigManager {
    
    // MARK: - Singleton
    static let shared = AIModelConfigManager()
    
    // MARK: - Properties
    
    /// The fast AI model name (e.g., "gemini-2.5-flash")
    /// Default fallback if Firebase fetch fails
    private(set) var fastModelName: String = "gemini-2.5-flash"
    
    /// The accurate/high-quality AI model name (e.g., "gemini-2.5-pro")
    /// Default fallback if Firebase fetch fails
    private(set) var accurateModelName: String = "gemini-2.5-pro"
    
    /// The current AI API key
    /// Default fallback if Firebase fetch fails
    private(set) var apiKey: String = "AIzaSyBbbQ-6XuKzJGIXjVQ_3ZY2GTlCahl3QIU"
    
    /// User's preferred model type (stored in UserDefaults)
    /// Rule: State Management - Persist user preference across app launches
    var modelPreference: AIModelPreference {
        didSet {
            UserDefaults.standard.set(modelPreference.rawValue, forKey: modelPreferenceKey)
            print("[AIConfig] Model preference updated to: \(modelPreference.displayName)") // Rule: General Coding - Add debug logs
        }
    }
    
    /// Firebase Remote Config instance
    private let remoteConfig: RemoteConfig
    
    /// Key for the fast AI model parameter in Firebase Remote Config
    private let fastModelKey = "ai_model_fast"
    
    /// Key for the accurate AI model parameter in Firebase Remote Config
    private let accurateModelKey = "ai_model_high"
    
    /// Key for the AI API key parameter in Firebase Remote Config
    private let apiKeyKey = "ai_api_key"
    
    /// Key for storing user's model preference in UserDefaults
    private let modelPreferenceKey = "ai_model_preference"
    
    // MARK: - Initialization
    
    private init() {
        print("[AIConfig] Initializing AIModelConfigManager") // Rule: General Coding - Add debug logs
        
        // Initialize Firebase Remote Config
        remoteConfig = RemoteConfig.remoteConfig()
        
        // Load user's saved preference or default to fast
        // Rule: General Coding - Provide sensible default (fast for better UX)
        if let savedPref = UserDefaults.standard.string(forKey: modelPreferenceKey),
           let preference = AIModelPreference(rawValue: savedPref) {
            modelPreference = preference
            print("[AIConfig] Loaded saved preference: \(preference.displayName)")
        } else {
            modelPreference = .fast
            print("[AIConfig] No saved preference, defaulting to: fast")
        }
        
        // Configure settings: fetch interval and timeout
        // Rule: Performance Optimization - Reasonable fetch interval to avoid excessive network calls
        let settings = RemoteConfigSettings()
        
        // Rule: General Coding - Use 0 interval in DEBUG mode for immediate fetches during development
        // In production, use 1-hour interval to reduce network calls
        #if DEBUG
        settings.minimumFetchInterval = 0 // DEBUG: Always fetch latest (no cache)
        print("[AIConfig] 🔧 DEBUG MODE: Fetch interval set to 0 (always fetch fresh)")
        #else
        settings.minimumFetchInterval = 3600 // PRODUCTION: Fetch at most once per hour
        #endif
        
        settings.fetchTimeout = 10 // Timeout after 10 seconds if network is slow
        remoteConfig.configSettings = settings
        
        // Set default values (used if Firebase fetch fails or hasn't happened yet)
        // Rule: General Coding - Always have a working fallback
        remoteConfig.setDefaults([
            fastModelKey: "gemini-2.5-flash" as NSObject,
            accurateModelKey: "gemini-2.5-pro" as NSObject,
            apiKeyKey: "AIzaSyBbbQ-6XuKzJGIXjVQ_3ZY2GTlCahl3QIU" as NSObject
        ])
        
        print("[AIConfig] Remote Config initialized with defaults - fast: gemini-2.5-flash, accurate: gemini-2.5-pro")
    }
    
    // MARK: - Public Methods
    
    /// Fetches the latest AI model configuration from Firebase Remote Config
    /// Call this when the app starts (e.g., in your App init or ContentView.onAppear)
    /// Rule: Swift Concurrency - Uses async/await for clean code
    func fetchConfiguration() async {
        print("[AIConfig] Starting Remote Config fetch...")
        
        do {
            // Fetch and activate in one call
            // Rule: General Coding - fetchAndActivate combines fetch + activate for simplicity
            let status = try await remoteConfig.fetchAndActivate()
            
            switch status {
            case .successFetchedFromRemote:
                print("[AIConfig] ✅ Successfully fetched NEW config from Firebase")
            case .successUsingPreFetchedData:
                print("[AIConfig] ✅ Using previously fetched config (still fresh)")
            case .error:
                print("[AIConfig] ⚠️ Fetch succeeded but activation had an error")
            @unknown default:
                print("[AIConfig] ⚠️ Unknown fetch status: \(status)")
            }
            
            // Get the fast model name from Remote Config
            let fetchedFastModel = remoteConfig.configValue(forKey: fastModelKey).stringValue ?? "gemini-2.5-flash"
            
            // Get the accurate model name from Remote Config
            let fetchedAccurateModel = remoteConfig.configValue(forKey: accurateModelKey).stringValue ?? "gemini-2.5-pro"
            
            // Get the API key from Remote Config
            let fetchedAPIKey = remoteConfig.configValue(forKey: apiKeyKey).stringValue ?? "AIzaSyBbbQ-6XuKzJGIXjVQ_3ZY2GTlCahl3QIU"
            
            // Update our stored values
            fastModelName = fetchedFastModel
            accurateModelName = fetchedAccurateModel
            apiKey = fetchedAPIKey
            print("[AIConfig] ✅ Fast model updated to: \(fastModelName)")
            print("[AIConfig] ✅ Accurate model updated to: \(accurateModelName)")
            print("[AIConfig] ✅ API key updated (length: \(apiKey.count) chars)")
            
        } catch {
            // If fetch fails, we keep using the default value
            // Rule: General Coding - Graceful degradation on network failure
            print("[AIConfig] ⚠️ Failed to fetch Remote Config: \(error.localizedDescription)")
            print("[AIConfig] Continuing with default models: fast=\(fastModelName), accurate=\(accurateModelName)")
        }
    }
    
    /// Returns the model name based on user's current preference
    /// Rule: General Coding - Computed property for dynamic model selection
    var currentModelName: String {
        switch modelPreference {
        case .fast:
            return fastModelName
        case .accurate:
            return accurateModelName
        }
    }
    
    /// Returns the full API endpoint URL for the current AI model (based on preference)
    /// Rule: General Coding - Encapsulate URL construction logic
    func getEndpointURL() -> URL {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(currentModelName):generateContent"
        guard let url = URL(string: urlString) else {
            // Fallback to hardcoded default if URL construction fails
            print("[AIConfig] ⚠️ Failed to construct URL for model: \(currentModelName), using default")
            return URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent")!
        }
        return url
    }
}
