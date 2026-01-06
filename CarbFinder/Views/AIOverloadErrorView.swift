//
//  AIOverloadErrorView.swift
//  CarbFinder
//
//  Error view shown when AI service is overloaded (503 error)
//  Rules Applied: General Coding (simplest approach), Apple Design Guidelines
//

import SwiftUI
import FirebaseFirestore

// MARK: - AIOverloadErrorView
struct AIOverloadErrorView: View {
    let onDismiss: () -> Void
    @State private var errorID: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Icon - adaptive color (black in light mode, white in dark mode)
            Image(systemName: "info.circle")
                .font(.system(size: 72))
                .foregroundStyle(.primary)
                .padding(.bottom, 24)
            
            // Title
            Text("Service Overloaded")
                .font(.title)
                .fontWeight(.bold)
                .padding(.bottom, 12)
            
            // Message
            Text("The AI service is currently overloaded. Please try again in a few moments.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            
            // "Did you know?" card with visible background
            VStack(alignment: .leading, spacing: 12) {
                // Card header with lightbulb icon
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.yellow)
                    Text("Did you know?")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                // Card content - restructured for clarity
                VStack(alignment: .leading, spacing: 12) {
                    
                    Text("If this error happens to you 3 times in one year, well send you a free sugar-free Nutella alternative. Enjoy!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("How to claim:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        
                        Text("1. Take a screenshot each time this appears")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(3)
                        
                        Text("2. Email screenshots to info@simplycode.eu")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(3)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(UIColor.systemGray6))
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            
            // Error ID
            VStack(spacing: 4) {
                Text("Error ID:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(errorID)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)
                    .textSelection(.enabled)
            }
            .padding(.bottom, 40)
            
            Spacer()
            
            // Return button
            Button {
                print("[AIOverloadError] Return tapped, errorID: \(errorID)")
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onDismiss()
            } label: {
                Text("Return")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            generateAndSaveErrorID()
        }
    }
    
    /// Generates a random 10-digit error ID and saves it to Firestore
    /// Rule: General Coding - Simplest approach with basic error handling
    private func generateAndSaveErrorID() {
        // Generate random 10-digit code
        let randomCode = String(format: "%010d", Int.random(in: 0...9999999999))
        errorID = randomCode
        print("[AIOverloadError] Generated error ID: \(errorID)")
        
        // Save to Firestore in "Error-IDs" collection
        let db = Firestore.firestore()
        let errorData: [String: Any] = [
            "errorID": errorID,
            "timestamp": Timestamp(date: Date()),
            "type": "ai_overload"
        ]
        
        db.collection("Error-IDs").document(errorID).setData(errorData) { error in
            if let error = error {
                print("[AIOverloadError] ❌ Failed to save error ID to Firestore: \(error)")
            } else {
                print("[AIOverloadError] ✅ Error ID saved to Firestore successfully")
            }
        }
    }
}

#Preview {
    NavigationStack {
        AIOverloadErrorView(onDismiss: { print("Preview dismiss") })
    }
}
