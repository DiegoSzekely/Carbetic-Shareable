//
//  UserInstallationManager.swift
//  CarbFinder
//
//  Created by Diego Szekely on 13.11.25.
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

/// Manages user installation date tracking to prevent reinstall bypass of trial periods
/// Rule: Security - Uses Firebase to persist installation date server-side
/// Rule: State Management - ObservableObject for @StateObject compatibility
final class UserInstallationManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// The date when the user first installed the app (nil if not yet determined)
    @Published private(set) var installationDate: Date?
    
    /// Whether we're currently loading the installation date from Firebase
    @Published private(set) var isLoading: Bool = true
    
    /// Error message if something went wrong
    @Published private(set) var errorMessage: String?
    
    /// The Firebase anonymous user UID (for testing/debugging purposes)
    /// This UID persists in iOS Keychain across app deletions
    @Published private(set) var userUID: String?
    
    // MARK: - Private Properties
    
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    
    /// Auth state change listener handle (to remove listener on deinit)
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    // MARK: - Constants
    
    private let userDefaultsKey = "app_installation_date"
    private let firestoreCollection = "users"
    private let firestoreField = "installationDate"
    
    // MARK: - Initialization
    
    init() {
        print("[InstallationManager] Initializing...") // Rule: General Coding - Add debug logs
        
        // Set up auth state listener to detect when Firebase changes the user
        // This handles cases where Firebase invalidates the anonymous token
        authStateHandle = auth.addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            if let user = user {
                print("[InstallationManager] 🔄 Auth state changed - User: \(user.uid)") // Rule: General Coding - Add debug logs
            } else {
                print("[InstallationManager] 🔄 Auth state changed - User signed out") // Rule: General Coding - Add debug logs
            }
        }
        
        Task {
            await initializeInstallationDate()
        }
    }
    
    deinit {
        // Clean up auth state listener
        if let handle = authStateHandle {
            auth.removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Public Methods
    
    /// Returns whether the user is within the trial period (first 3 days)
    /// - Returns: true if within trial period, false otherwise
    func isWithinTrialPeriod() -> Bool {
        guard let installDate = installationDate else {
            print("[InstallationManager] No installation date available yet") // Rule: General Coding - Add debug logs
            return false
        }
        
        // Rule: Subscriptions - 3-day free trial period for new users
        let daysSinceInstall = Calendar.current.dateComponents([.day], from: installDate, to: Date()).day ?? 0
        let withinTrial = daysSinceInstall < 3
        
        print("[InstallationManager] Days since install: \(daysSinceInstall), within trial: \(withinTrial)") // Rule: General Coding - Add debug logs
        return withinTrial
    }
    
    /// Returns the number of days remaining in the trial period (0 if trial expired or no date)
    /// - Returns: Number of days remaining (0-3)
    func daysRemainingInTrial() -> Int {
        guard let installDate = installationDate else { return 0 }
        
        // Rule: Subscriptions - Calculate days remaining in 3-day trial period
        let daysSinceInstall = Calendar.current.dateComponents([.day], from: installDate, to: Date()).day ?? 0
        let remaining = max(0, 3 - daysSinceInstall)
        
        return remaining
    }
    
    // MARK: - Private Methods
    
    /// Initializes the installation date by checking local storage first, then Firebase
    /// Rule: General Coding - Async/await for clean concurrent code
    @MainActor
    private func initializeInstallationDate() async {
        print("[InstallationManager] Starting installation date initialization") // Rule: General Coding - Add debug logs
        
        // Step 1: Check if we have a locally cached installation date
        if let localDate = UserDefaults.standard.object(forKey: userDefaultsKey) as? Date {
            print("[InstallationManager] Found local installation date: \(localDate)") // Rule: General Coding - Add debug logs
            self.installationDate = localDate
        }
        
        // Step 2: Authenticate user anonymously if not already authenticated
        // Rule: Security - Anonymous auth ensures each user gets unique server-side record
        do {
            let user = try await authenticateUser()
            print("[InstallationManager] User authenticated: \(user.uid)") // Rule: General Coding - Add debug logs
            
            // Step 3: Check Firebase for installation date
            print("[InstallationManager] 🚀 About to call fetchOrCreateInstallationDate...") // Rule: General Coding - Add debug logs
            try await fetchOrCreateInstallationDate(uid: user.uid)
            print("[InstallationManager] ✅ fetchOrCreateInstallationDate completed successfully") // Rule: General Coding - Add debug logs
            
            self.isLoading = false
            print("[InstallationManager] ✅ Initialization complete. installationDate = \(String(describing: self.installationDate))") // Rule: General Coding - Add debug logs
            
        } catch {
            print("[InstallationManager] ❌❌❌ ERROR CAUGHT: \(error)") // Rule: General Coding - Add debug logs
            print("[InstallationManager] ❌ Error localized: \(error.localizedDescription)") // Rule: General Coding - Add debug logs
            let nsError = error as NSError
            print("[InstallationManager] ❌ Error domain: \(nsError.domain)") // Rule: General Coding - Add debug logs
            print("[InstallationManager] ❌ Error code: \(nsError.code)") // Rule: General Coding - Add debug logs
            print("[InstallationManager] ❌ Error userInfo: \(nsError.userInfo)") // Rule: General Coding - Add debug logs
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }
    
    /// Authenticates the user anonymously if not already authenticated
    /// Rule: Security - Uses Firebase Anonymous Auth for unique user identification
    private func authenticateUser() async throws -> User {
        // Check if user is already signed in
        if let currentUser = auth.currentUser {
            print("[InstallationManager] User found in Keychain: \(currentUser.uid)") // Rule: General Coding - Add debug logs
            
            // IMPORTANT: Verify the token is still valid by attempting to refresh it
            // This prevents using stale tokens that Firebase will silently replace
            do {
                // Force token refresh to ensure it's valid
                let _ = try await currentUser.getIDToken(forcingRefresh: true)
                print("[InstallationManager] ✅ Token is valid, user authenticated: \(currentUser.uid)") // Rule: General Coding - Add debug logs
                
                // Update the published UID property
                await MainActor.run {
                    self.userUID = currentUser.uid
                }
                
                return currentUser
            } catch {
                // Token is invalid/expired - Firebase will have signed out the user
                print("[InstallationManager] ⚠️ Token invalid, will sign in again: \(error.localizedDescription)") // Rule: General Coding - Add debug logs
                // Fall through to sign in anonymously again
            }
        }
        
        // Sign in anonymously (either first time or after token invalidation)
        print("[InstallationManager] Signing in anonymously...") // Rule: General Coding - Add debug logs
        let authResult = try await auth.signInAnonymously()
        print("[InstallationManager] ✅ New user signed in: \(authResult.user.uid)") // Rule: General Coding - Add debug logs
        
        // Update the published UID property
        await MainActor.run {
            self.userUID = authResult.user.uid
        }
        
        return authResult.user
    }
    
    /// Fetches installation date from Firebase, or creates it if it doesn't exist
    /// Rule: Security - Server-side persistence prevents reinstall bypass
    @MainActor
    private func fetchOrCreateInstallationDate(uid: String) async throws {
        let docRef = db.collection(firestoreCollection).document(uid)
        
        // Try to fetch existing document
        let snapshot = try await docRef.getDocument()
        
        if snapshot.exists, let data = snapshot.data(), let timestamp = data[firestoreField] as? Timestamp {
            // Installation date exists in Firebase
            let firebaseDate = timestamp.dateValue()
            print("[InstallationManager] Found Firebase installation date: \(firebaseDate)") // Rule: General Coding - Add debug logs
            
            self.installationDate = firebaseDate
            
            // Cache locally for faster access
            UserDefaults.standard.set(firebaseDate, forKey: userDefaultsKey)
            
        } else {
            // No installation date exists - this is a new user
            let now = Date()
            print("[InstallationManager] Creating new installation date: \(now)") // Rule: General Coding - Add debug logs
            
            // Save to Firebase
            try await docRef.setData([
                firestoreField: Timestamp(date: now),
                "createdAt": Timestamp(date: now)
            ])
            
            self.installationDate = now
            
            // Cache locally
            UserDefaults.standard.set(now, forKey: userDefaultsKey)
        }
    }
}
