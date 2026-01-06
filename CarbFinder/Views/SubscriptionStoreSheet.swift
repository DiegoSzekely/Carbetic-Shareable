import SwiftUI
import StoreKit

struct SubscriptionStoreSheet: View {
    
    @Binding var isPresented: Bool
    
    /// Optional custom title for the header
    /// Rule: General Coding - Allow customization for different contexts
    /// Default: nil (shows animated tagline), Alternative: "Choose your plan"
    var customTitle: String? = nil
    
    var body: some View {
        SubscriptionStoreView(
            productIDs: ["PremiumStandardSub", "unlimited"],
            marketingContent: {
                // MARK: - Header Content
                VStack(alignment: .leading, spacing: 12) {
                    
                    // 1. Top Spacer: Pushes text towards the middle
                    Spacer()
                    
                    // Rule: General Coding - Show custom title if provided, otherwise show animated tagline
                    if let customTitle = customTitle {
                        // Custom title (e.g., "Choose your plan")
                        Text(customTitle)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        // Subtitle text:
                        // Using .secondary for standard system gray
                        Text("Select the plan that works best for you.")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    } else {
                        // Default: Animated tagline
                        // textColor: .primary (Black in Light Mode, White in Dark Mode)
                        // accentColor: .blue (Your requested blue accent)
                        // enableHaptics: false (no haptic feedback in subscription sheet)
                        // enableShimmer: true (shimmer enabled - will only show in light mode)
                        AnimatedTaglineView(
                            animateWords: true,
                            textColor: .primary,
                            accentColor: .blue,
                            enableHaptics: false,
                            enableShimmer: true
                        )
                        .id(isPresented) // Force re-initialization when sheet opens
                        
                        // Subtitle text:
                        // Using .secondary for standard system gray
                        Text("Get back to eating what you love.")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    
                    // 2. Bottom Spacer: Balances the text
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        )
        // MARK: - The "Swoosh" / Sticky Bottom Logic
        // This puts the plan picker and button in a tray at the bottom
        .subscriptionStoreControlStyle(.prominentPicker)
        
        // MARK: - Visual Styling
        // Ensures the button matches the text accent
        .tint(.blue)
        
        // MARK: - Purchase Logic
        .onInAppPurchaseCompletion { product, result in
            if case .success(.success(let verificationResult)) = result {
                switch verificationResult {
                case .verified(let transaction):
                    print("Purchase successful: \(transaction.productID)")
                    isPresented = false
                case .unverified(_, _):
                    break
                }
            }
        }
    }
}

#Preview("Default - Animated Tagline") {
    SubscriptionStoreSheet(isPresented: .constant(true))
}
#Preview("Custom Title - Choose Plan") {
    SubscriptionStoreSheet(isPresented: .constant(true), customTitle: "Choose your plan")
}

