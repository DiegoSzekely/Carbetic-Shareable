import SwiftUI

struct HowToCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    // MARK: - Angles section
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Take three photos")
                            .font(.largeTitle.weight(.bold)) // Made larger and bold
                            .foregroundStyle(.primary)
 
                    }


                    VStack(spacing: 50) { // Increased from 33 to 55 for more spacing between angle images
                        AngleRow(numberSymbol: "1.circle.fill", imageName: "fromabove", title: "From above (90°)", description: "Hold the camera directly above the plate to capture the full layout.")
                        AngleRow(numberSymbol: "2.circle.fill", imageName: "from45deg", title: "Slight angle (45°)", description: "Tilt the camera to show depth and height of the meal.")
                        AngleRow(numberSymbol: "3.circle.fill", imageName: "from90deg", title: "Side (near 0°)", description: "Capture from the side to highlight layers and textures.")
                    }

                    // MARK: - Reference item instruction section
                    ReferenceItemBox()
                        .padding(.top, 45) // Add spacing to separate from angle images above
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(
                                Color(.label),         // Outside circle - adapts to light/dark mode, stronger visibility
                                Color(.secondaryLabel) // Inside X - provides good contrast in both modes
                            )
                    }
                }
            }
            .interactiveDismissDisabled(true)
        }
    }
}

private struct ReferenceItemBox: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Always include a reference item")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
            
            Text("Good examples:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 16) {
                ReferenceItem(symbol: "eurosign.circle.fill", name: "Coin")
                ReferenceItem(symbol: "batteryblock.fill", name: "Lego brick")
                ReferenceItem(symbol: "airpods", name: "Airpods")
                Spacer()
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.quaternary, lineWidth: 1)
        )
    }
}

private struct ReferenceItem: View {
    let symbol: String
    let name: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
                .frame(width: 32, height: 32)
            
            Text(name)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(minWidth: 60)
    }
}


private struct InstructionRow: View {
    let symbol: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct AngleRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let numberSymbol: String
    let imageName: String
    let title: String
    let description: String

    var body: some View {
        GeometryReader { geo in
            // Use HStack with image on left (25% width), text on right
            HStack(alignment: .center, spacing: 15) {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width * 0.37, height: geo.size.width * 0.37)
                    .clipped()
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(.quaternary, lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: numberSymbol)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(colorScheme == .dark ? AnyShapeStyle(.white) : AnyShapeStyle(.tint))
                            .font(.title2.weight(.semibold)) // Keep the larger SF symbol size
                        Text(title)
                            .font(.headline) // Reduced back to .headline from .title3
                    }
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
        }
        .frame(height: 96)
    }
}

private struct TipItem: View {
    let symbol: String
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 22)
                .accessibilityHidden(true)
            Text(title)
                .font(.subheadline)
        }
    }
}



#Preview("HowToCaptureSheet") {
    HowToCaptureSheet()
}
