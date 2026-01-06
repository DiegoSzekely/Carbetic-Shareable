import SwiftUI

struct HowAIWorksSheetView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    let horizontalContentPadding: CGFloat = 20

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Step 1 (SF Symbol)
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "square.3.layers.3d.down.right")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.primary)
                            .imageScale(.large)
                        Text("The images are analyzed using a (custom trained) Multimodal Large Language Model (MLLM)")
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, horizontalContentPadding)
                    
                    Divider()
                        .padding(.horizontal, horizontalContentPadding)

                    // Step 2 with custom image asset
                    HStack(alignment: .top, spacing: 12) {
                        Image(colorScheme == .dark ? "graph3d-darkmode" : "graph3d-lightmode")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .foregroundStyle(.primary)
                        Text("The volume of individual components is estimated.")
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, horizontalContentPadding)
                    
                    Divider()
                        .padding(.horizontal, horizontalContentPadding)

                    // Step 3 (SF Symbol)
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "scalemass")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.primary)
                            .imageScale(.large)
                        Text("Typical food densities are used to convert the estimated volumes into approximate weights")
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, horizontalContentPadding)
                    
                    Divider()
                        .padding(.horizontal, horizontalContentPadding)

                    // Step 4 (SF Symbol)
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "text.page.badge.magnifyingglass")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.primary)
                            .imageScale(.large)
                        Text("Each component's carb percentage is sourced online to calculate the carb content in each component")
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, horizontalContentPadding)
                    
                    Divider()
                        .padding(.horizontal, horizontalContentPadding)

                    // Step 5 (SF Symbol)
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.primary)
                            .imageScale(.large)
                        Text("The carbs of each component are added to give the total net carbohydrates")
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, horizontalContentPadding)
                    
                    // Visual separator for the disclaimer section
                    Spacer()
                        .frame(height: 20)
                    
                    // Confidence disclaimer (visually distinct)
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "info.bubble")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.tint)
                            .imageScale(.large)
                        Text("If the MLLM has particularly low confidence, the Results page will show \"Low confidence\"")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal, horizontalContentPadding)
                }
                .padding(.top, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("How it works")
            //.navigationBarTitleDisplayMode()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Dismiss")
                    }
                }
            }
        }
    }
}

#Preview {
    HowAIWorksSheetView()
}
