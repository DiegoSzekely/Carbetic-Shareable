//
//  DisclaimerManager.swift
//  CarbFinder
//
//  Created by Diego Szekely on 20.11.25.
//  Manages disclaimer acceptance state and Firestore logging
//  Rule: General Coding - Simple, device-based tracking with server-side logging
//
//  ⚠️ MANDATORY DISCLAIMER FUNCTIONALITY COMMENTED OUT ⚠️
//  The disclaimer is still accessible from result views but no longer required on first use.
//  Firebase logging is disabled. The DisclaimerView file itself remains intact.

import Foundation
import FirebaseAuth
import FirebaseFirestore
import SwiftUI

// MARK: - DISCLAIMER FUNCTIONALITY - COMMENTED OUT - START

/// Manages disclaimer acceptance state (device-based) and logs acceptances to Firestore
/// Rule: Security - Device-based flag (@AppStorage), server-side logging for audit trail
/// Rule: State Management - Simple @AppStorage for device-level persistence
//final class DisclaimerManager {
//    
//    // MARK: - Singleton
//    
//    static let shared = DisclaimerManager()
//    
//    // MARK: - Private Properties
//    
//    private let db = Firestore.firestore()
//    private let auth = Auth.auth()
//    
//    // MARK: - Constants
//    
//    private let firestoreCollection = "disclaimer_acceptances"
//    
//    // MARK: - Private Initializer
//    
//    private init() {
//        print("[DisclaimerManager] Initialized") // Rule: General Coding - Add debug logs
//    }
//    
//    // MARK: - Public Methods
//    
//    /// Records disclaimer acceptance to Firestore
//    /// Rule: Security - Logs acceptance with timestamp for audit trail
//    /// - Note: Uses anonymous auth to create unique record per device/user
//    /// - Note: Also updates the user document in "users" collection with disclaimer acceptance array
//    func recordAcceptance() async {
//        print("[DisclaimerManager] Recording disclaimer acceptance...") // Rule: General Coding - Add debug logs
//        
//        do {
//            // Authenticate anonymously if needed
//            let user = try await authenticateUser()
//            print("[DisclaimerManager] User authenticated: \(user.uid)") // Rule: General Coding - Add debug logs
//            
//            let now = Date()
//            let timestamp = Timestamp(date: now)
//            
//            // Create acceptance record
//            let acceptanceData: [String: Any] = [
//                "timestamp": timestamp,
//                "userId": user.uid,
//                "version": "1.0" // Version of disclaimer accepted
//            ]
//            
//            // Add to Firestore collection (for audit trail redundancy)
//            // Rule: General Coding - Use addDocument to allow multiple acceptances per user
//            let docRef = try await db.collection(firestoreCollection).addDocument(data: acceptanceData)
//            print("[DisclaimerManager] ✅ Acceptance recorded in collection with ID: \(docRef.documentID)") // Rule: General Coding - Add debug logs
//            
//            // ALSO update the user document in "users" collection with FULL TRAIL
//            // Rule: General Coding - Add disclaimer acceptance to array in user document
//            let userDocRef = db.collection("users").document(user.uid)
//            
//            // Create acceptance entry for the array
//            let acceptanceEntry: [String: Any] = [
//                "timestamp": timestamp,
//                "version": "1.0"
//            ]
//            
//            // Use arrayUnion to append to the acceptances array without overwriting
//            // This automatically creates the array if it doesn't exist
//            try await userDocRef.setData([
//                "disclaimerAcceptances": FieldValue.arrayUnion([acceptanceEntry]),
//                "lastDisclaimerAcceptedAt": timestamp // Also keep the most recent one for easy access
//            ], merge: true) // merge: true ensures we don't overwrite existing fields like installationDate
//            print("[DisclaimerManager] ✅ User document updated with disclaimer acceptance trail") // Rule: General Coding - Add debug logs
//            
//        } catch {
//            print("[DisclaimerManager] ❌ Error recording acceptance: \(error)") // Rule: General Coding - Add debug logs
//            // Don't fail the app if logging fails - user has already accepted locally
//        }
//    }
//    
//    // MARK: - Private Methods
//    
//    /// Authenticates the user anonymously if not already authenticated
//    /// Rule: Security - Uses Firebase Anonymous Auth for unique user identification
//    private func authenticateUser() async throws -> User {
//        // Check if user is already signed in
//        if let currentUser = auth.currentUser {
//            print("[DisclaimerManager] User found in Keychain: \(currentUser.uid)") // Rule: General Coding - Add debug logs
//            
//            // Verify the token is still valid by attempting to refresh it
//            do {
//                let _ = try await currentUser.getIDToken(forcingRefresh: true)
//                print("[DisclaimerManager] ✅ Token is valid, user authenticated: \(currentUser.uid)") // Rule: General Coding - Add debug logs
//                return currentUser
//            } catch {
//                print("[DisclaimerManager] ⚠️ Token invalid, will sign in again: \(error.localizedDescription)") // Rule: General Coding - Add debug logs
//                // Fall through to sign in anonymously again
//            }
//        }
//        
//        // Sign in anonymously (either first time or after token invalidation)
//        print("[DisclaimerManager] Signing in anonymously...") // Rule: General Coding - Add debug logs
//        let authResult = try await auth.signInAnonymously()
//        print("[DisclaimerManager] ✅ New user signed in: \(authResult.user.uid)") // Rule: General Coding - Add debug logs
//        
//        return authResult.user
//    }
//}
//
///// AppStorage key for tracking disclaimer acceptance on device
///// Rule: State Management - Simple device-level flag, independent of user/installation tracking
//extension UserDefaults {
//    static let disclaimerAcceptedKey = "has_accepted_disclaimer"
//}
//
///// Property wrapper for disclaimer acceptance state
///// Rule: State Management - Use @AppStorage for automatic persistence and SwiftUI integration
//struct DisclaimerAccepted {
//    @AppStorage(UserDefaults.disclaimerAcceptedKey) var value: Bool = false
//}

// MARK: - DISCLAIMER FUNCTIONALITY - COMMENTED OUT - END

