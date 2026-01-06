import SwiftUI

//
//  DiscoverTypeOneView.swift
//  CarbFinder
//
//  ARCHIVED - No longer in use as of recipe scanning feature implementation
//  This file can be deleted or kept for reference
//

struct DiscoverTypeOneView: View {
    var body: some View {
        NavigationView {
            ZStack {
                // Multi-layered patched background for depth and visual interest
                // Layer 1: Base gradient with warm-cool contrast
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.92, green: 0.94, blue: 0.98), // Cool light blue-white
                        Color(red: 0.96, green: 0.92, blue: 0.88), // Warm cream
                        Color(red: 0.88, green: 0.94, blue: 0.92), // Soft sage green
                        Color(red: 0.94, green: 0.90, blue: 0.95)  // Subtle lavender
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Layer 2: Organic patch - top left warm glow
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.98, green: 0.94, blue: 0.85).opacity(0.7),
                        Color.clear
                    ]),
                    center: UnitPoint(x: 0.15, y: 0.2),
                    startRadius: 30,
                    endRadius: 300
                )
                .ignoresSafeArea()
                
                // Layer 3: Cool patch - center right
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.85, green: 0.92, blue: 0.98).opacity(0.6),
                        Color.clear
                    ]),
                    center: UnitPoint(x: 0.8, y: 0.4),
                    startRadius: 40,
                    endRadius: 280
                )
                .ignoresSafeArea()
                
                // Layer 4: Mint patch - bottom center
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.82, green: 0.96, blue: 0.90).opacity(0.8),
                        Color.clear
                    ]),
                    center: UnitPoint(x: 0.5, y: 0.75),
                    startRadius: 50,
                    endRadius: 350
                )
                .ignoresSafeArea()
                
                // Layer 5: Subtle pink patch - top right
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.96, green: 0.90, blue: 0.94).opacity(0.5),
                        Color.clear
                    ]),
                    center: UnitPoint(x: 0.85, y: 0.15),
                    startRadius: 20,
                    endRadius: 200
                )
                .ignoresSafeArea()
                
                // Layer 6: Overlay texture for depth
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.1),
                        Color.clear,
                        Color.black.opacity(0.02)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .accessibilityHidden(true)
                
                // ScrollView with 8 alternating cards
                GeometryReader { geometry in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 18) {
                            ForEach(0..<8, id: \.self) { index in
                                HStack {
                                    if index % 2 == 0 {
                                        // Left-aligned card with individual tilting
                                        CardView(cardNumber: index + 1, isLeftAligned: true)
                                            .frame(
                                                width: geometry.size.width * 0.4,
                                                height: geometry.size.width * 0.55
                                            )
                                            .rotationEffect(.degrees(getLeftCardRotation(for: index)))
                                            .offset(x: 10, y: CGFloat(index * 5))
                                        Spacer()
                                    } else {
                                        // Right-aligned card with individual tilting
                                        Spacer()
                                        CardView(cardNumber: index + 1, isLeftAligned: false)
                                            .frame(
                                                width: geometry.size.width * 0.4,
                                                height: geometry.size.width * 0.55
                                            )
                                            .rotationEffect(.degrees(getRightCardRotation(for: index)))
                                            .offset(x: -10, y: CGFloat(index * 5))
                                    }
                                }
                                .padding(.horizontal, 30)
                            }
                        }
                        .padding(.top, 30)
                        .padding(.bottom, 80)
                    }
                }
            }
            .navigationTitle("Discover Type One")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // Helper functions to create beautiful individual card rotations
    private func getLeftCardRotation(for index: Int) -> Double {
        let rotations: [Double] = [-8.0, -3.5, -6.2, -4.8]
        return rotations[index / 2 % rotations.count]
    }
    
    private func getRightCardRotation(for index: Int) -> Double {
        let rotations: [Double] = [6.5, 4.2, 7.8, 3.9]
        return rotations[index / 2 % rotations.count]
    }
}

struct CardView: View {
    let cardNumber: Int
    let isLeftAligned: Bool
    
    var body: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(.regularMaterial)
            .overlay(
                // Enhanced inner glow effect with multiple layers
                RoundedRectangle(cornerRadius: 22)
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.2),
                                Color.clear
                            ]),
                            center: .topLeading,
                            startRadius: 10,
                            endRadius: 150
                        )
                    )
            )
            .overlay(
                // Subtle inner border highlight
                RoundedRectangle(cornerRadius: 22)
                    .stroke(
                        Color.white.opacity(0.8),
                        lineWidth: 0.5
                    )
                    .padding(1)
            )
            .overlay(
                // Main gradient border
                RoundedRectangle(cornerRadius: 22)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.7),
                                Color.gray.opacity(0.15),
                                Color.white.opacity(0.3)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.8
                    )
            )
            .overlay(
                VStack(spacing: 12) {
                    // Card icon/symbol
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Text("\(cardNumber)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    
                    // Card title
                    Text("Type \(cardNumber)")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    // Subtitle
                    Text("Discover more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .opacity(0.8)
                }
                .padding()
            )
            .shadow(
                color: isLeftAligned ? 
                    Color.black.opacity(0.06) : Color.black.opacity(0.1),
                radius: isLeftAligned ? 12 : 16,
                x: isLeftAligned ? -4 : 4,
                y: 8
            )
            .shadow(
                color: isLeftAligned ? 
                    Color.black.opacity(0.03) : Color.black.opacity(0.05),
                radius: isLeftAligned ? 6 : 8,
                x: isLeftAligned ? -2 : 2,
                y: 4
            )
            .scaleEffect(0.96)
            .animation(.easeInOut(duration: 0.3), value: cardNumber)
    }
}

#Preview {
    DiscoverTypeOneView()
}
