//
//  NoContentErrorView.swift
//  CarbFinder
//
//  Error view shown when AI detects no food/recipe in images or inaccessible URL
//  Rules Applied: General Coding (simplest approach), Apple Design Guidelines
//

import SwiftUI

// MARK: - Error Type Enum
/// Represents different types of content detection errors
enum ContentDetectionError {
    case noFoodInImages
    case noRecipeInImages
    case invalidRecipeURL
    case inaccessibleURL
    
    var title: String {
        switch self {
        case .noFoodInImages:
            return "No Food Detected"
        case .noRecipeInImages:
            return "No Recipe Detected"
        case .invalidRecipeURL:
            return "Not a Recipe"
        case .inaccessibleURL:
            return "Can't Access Page"
        }
    }
    
    var icon: String {
        switch self {
        case .noFoodInImages:
            return "fork.knife.circle"
        case .noRecipeInImages:
            return "book.pages"
        case .invalidRecipeURL:
            return "link.circle"
        case .inaccessibleURL:
            return "exclamationmark.triangle"
        }
    }
    
    var message: String {
        switch self {
        case .noFoodInImages:
            return "We couldn't find any food in the photos you captured. Please try again with images that clearly show your meal."
        case .noRecipeInImages:
            return "We couldn't find a recipe in the photo you captured. Please try again with a clear image of a recipe."
        case .invalidRecipeURL:
            return "The URL you provided doesn't appear to contain a recipe. Please try again with a link to a recipe page."
        case .inaccessibleURL:
            return "We couldn't access the webpage at the URL you provided. Please check the link and try again."
        }
    }
}

// MARK: - NoContentErrorView
struct NoContentErrorView: View {
    let errorType: ContentDetectionError
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Icon
            Image(systemName: errorType.icon)
                .font(.system(size: 72))
                .foregroundStyle(.secondary)
                .padding(.bottom, 24)
            
            // Title
            Text(errorType.title)
                .font(.title)
                .fontWeight(.bold)
                .padding(.bottom, 12)
            
            // Message
            Text(errorType.message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            
            Spacer()
            
            // Return home button
            Button {
                print("[NoContentError] Return home tapped") // Rule: General Coding - Add debug logs
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
            .padding(.horizontal, 24) // Rule: Apple Design Guidelines - Reduced from 32 to 24 for wider button
            .padding(.bottom, 40)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }
}

#Preview("No Food") {
    NavigationStack {
        NoContentErrorView(
            errorType: .noFoodInImages,
            onDismiss: { print("Preview dismiss") }
        )
    }
}

#Preview("No Recipe") {
    NavigationStack {
        NoContentErrorView(
            errorType: .noRecipeInImages,
            onDismiss: { print("Preview dismiss") }
        )
    }
}

#Preview("Invalid URL") {
    NavigationStack {
        NoContentErrorView(
            errorType: .invalidRecipeURL,
            onDismiss: { print("Preview dismiss") }
        )
    }
}
