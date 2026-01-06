//
//  HistoryView.swift
//  CarbFinder
//
//  Created by Diego Szekely on 13.11.25.
// THIS IS THE VIEW WHERE ALL OF THE PAST MEALS/RECIPES WILL BE PRESENTED

import SwiftUI

// Rule: State Management - Use @Observable for view model
// Rule: General Coding - Add debug logs & comments for easier debug & readability
@Observable
final class HistoryViewModel {
    var searchText: String = ""
    var selectedFilter: HistoryFilter = .all
    
    enum HistoryFilter: String, CaseIterable {
        case all = "All"
        case meals = "Meals"
        case recipes = "Recipes"
    }
    
    /// Helper to determine if JSON is from a recipe scan or meal scan
    /// Recipe scans have "portionsCount", "portions", or "recipeDescription"
    /// Meal scans have "components"
    func isRecipeScan(json: String?) -> Bool {
        guard let json = json else { return false }
        return json.contains("portionsCount") || json.contains("portions") || json.contains("recipeDescription")
    }
    
    /// Extracts recipe description from AI result JSON
    /// Rule: General Coding - Helper function for parsing recipe description
    func getRecipeDescription(from json: String?) -> String? {
        guard let json = json,
              let data = json.data(using: .utf8) else { return nil }
        
        do {
            if let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let description = decoded["recipeDescription"] as? String {
                return description
            }
        } catch {
            print("[HistoryViewModel] Failed to parse recipe description: \(error)")
        }
        return nil
    }
    
    /// Extracts meal summary/description from AI result JSON
    /// Rule: General Coding - Helper function for parsing meal summary for search
    func getMealSummary(from json: String?) -> String? {
        guard let json = json,
              let data = json.data(using: .utf8) else { return nil }
        
        do {
            if let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let summary = decoded["mealSummary"] as? String {
                return summary
            }
        } catch {
            print("[HistoryViewModel] Failed to parse meal summary: \(error)")
        }
        return nil
    }
    
    /// Extracts all component descriptions from AI result JSON (for meals)
    /// Rule: General Coding - Helper function for searching meal components
    func getMealComponents(from json: String?) -> [String] {
        guard let json = json,
              let data = json.data(using: .utf8) else { return [] }
        
        do {
            if let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let components = decoded["components"] as? [[String: Any]] {
                return components.compactMap { $0["description"] as? String }
            }
        } catch {
            print("[HistoryViewModel] Failed to parse meal components: \(error)")
        }
        return []
    }
    
    /// Filters entries based on search text and selected filter
    func filteredEntries(from entries: [ScanEntry]) -> [ScanEntry] {
        var filtered = entries
        
        // Apply filter by type
        switch selectedFilter {
        case .all:
            break // Show all entries
        case .meals:
            filtered = filtered.filter { !isRecipeScan(json: $0.aiResultJSON) }
        case .recipes:
            filtered = filtered.filter { isRecipeScan(json: $0.aiResultJSON) }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { entry in
                // Rule: General Coding - Comprehensive search across all relevant fields
                let searchLower = searchText.lowercased()
                
                // Search in carb estimate
                let carbMatch = entry.carbEstimate.lowercased().contains(searchLower)
                
                // Search in date
                let dateMatch = entry.date.formatted(.dateTime.month().day().year()).lowercased().contains(searchLower)
                
                // Search in recipe description (for recipe entries)
                var recipeDescMatch = false
                if isRecipeScan(json: entry.aiResultJSON),
                   let recipeDesc = getRecipeDescription(from: entry.aiResultJSON) {
                    recipeDescMatch = recipeDesc.lowercased().contains(searchLower)
                }
                
                // Search in meal summary (for meal entries)
                var mealSummaryMatch = false
                if !isRecipeScan(json: entry.aiResultJSON),
                   let mealSummary = getMealSummary(from: entry.aiResultJSON) {
                    mealSummaryMatch = mealSummary.lowercased().contains(searchLower)
                }
                
                // Search in meal components/ingredients
                var componentMatch = false
                if !isRecipeScan(json: entry.aiResultJSON) {
                    let components = getMealComponents(from: entry.aiResultJSON)
                    componentMatch = components.contains { $0.lowercased().contains(searchLower) }
                }
                
                // Fallback: search in raw JSON if nothing else matched
                let jsonMatch = entry.aiResultJSON?.lowercased().contains(searchLower) ?? false
                
                return carbMatch || dateMatch || recipeDescMatch || mealSummaryMatch || componentMatch || jsonMatch
            }
        }
        
        print("[HistoryView] Filtered \(entries.count) entries to \(filtered.count) (filter: \(selectedFilter.rawValue), search: '\(searchText)')") // Rule: General Coding - Add debug logs
        return filtered
    }
}

// Rule: State Management - Use appropriate property wrappers
struct HistoryView: View {
    // Rule: State Management - Use @EnvironmentObject to access app-wide history store
    @EnvironmentObject var historyStore: ScanHistoryStore
    
    // Rule: State Management - Use let for view model observation with @Observable
    let viewModel = HistoryViewModel()
    
    // Rule: State Management - Use @State for local view-managed state
    @State private var mealEntryToShow: ScanEntry?
    @State private var recipeEntryToShow: ScanEntry?
    @State private var selectedIsLoading = false
    
    @Environment(\.colorScheme) private var colorScheme
    
    // Card dimensions matching ContentView
    private let cardWidth = UIScreen.main.bounds.width * 0.45
    private let cardHeight = UIScreen.main.bounds.height * 0.25
    private let cardSpacing: CGFloat = 12
    
    // Rule: Performance Optimization - Computed property for columns
    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: cardSpacing),
            GridItem(.flexible(), spacing: cardSpacing)
        ]
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Filter buttons
                    filterButtons
                    
                    // Cards grid
                    cardsGrid
                }
                .padding(.horizontal, cardSpacing)
                .padding(.bottom, 20)
            }
            .navigationTitle("History") // Rule: General Coding - Large title style
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: Binding(
                    get: { viewModel.searchText },
                    set: { viewModel.searchText = $0 }
                ),
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search meals and recipes"
            ) // Rule: General Coding - Apple Design/UI/UX guidelines (classic Apple search bar like Maps)
        }
        // Rule: SwiftUI-specific Patterns - Present sheets for result views
        // Use item-based sheet presentation for reliable state management
        .sheet(item: $mealEntryToShow) { entry in
            NavigationStack {
                ResultView(
                    resultText: Binding(
                        get: { entry.aiResultJSON },
                        set: { _ in }
                    ),
                    isLoading: $selectedIsLoading,
                    onDone: { mealEntryToShow = nil },
                    showHomeInQuickAccessBar: false
                )
            }
            .presentationDetents([.large])
        }
        .sheet(item: $recipeEntryToShow) { entry in
            NavigationStack {
                RecipeResultView(
                    resultText: Binding(
                        get: { entry.aiResultJSON },
                        set: { _ in }
                    ),
                    isLoading: $selectedIsLoading,
                    // Rule: State Management - For link-based recipes, don't pass image (pass nil)
                    // This ensures RecipeResultView shows the correct navbar button (link vs image)
                    recipeImage: entry.recipeURLString != nil ? nil : historyStore.image(for: entry),
                    recipeURL: entry.recipeURLString.flatMap { URL(string: $0) },
                    onDone: { recipeEntryToShow = nil },
                    showHomeInQuickAccessBar: false
                )
            }
            .presentationDetents([.large])
        }
    }
    
    // MARK: - Filter Buttons
    // Rule: General Coding - Keep the codebase very clean and organized
    private var filterButtons: some View {
        HStack(spacing: 8) {
            ForEach(HistoryViewModel.HistoryFilter.allCases, id: \.self) { filter in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectedFilter = filter
                    }
                    print("[HistoryView] Filter changed to: \(filter.rawValue)") // Rule: General Coding - Add debug logs
                } label: {
                    Text(filter.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(viewModel.selectedFilter == filter ? .primary : .secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            viewModel.selectedFilter == filter
                                ? Color.primary.opacity(0.15)
                                : Color.clear
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(
                                    viewModel.selectedFilter == filter
                                        ? Color.primary.opacity(0.3)
                                        : Color.secondary.opacity(0.2),
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
        .padding(.top, 8)
    }
    
    // MARK: - Cards Grid
    // Rule: Performance Optimization - Implement lazy loading for large lists using LazyVGrid
    private var cardsGrid: some View {
        let filtered = viewModel.filteredEntries(from: historyStore.entries)
        
        return Group {
            if filtered.isEmpty {
                emptyStateView
            } else {
                LazyVGrid(columns: columns, spacing: cardSpacing) {
                    ForEach(filtered) { entry in
                        cardView(for: entry)
                    }
                }
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: viewModel.searchText.isEmpty ? "tray" : "magnifyingglass")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 4) {
                Text(viewModel.searchText.isEmpty ? "No entries yet" : "No results found")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Text(viewModel.searchText.isEmpty
                     ? "Your captured meals and recipes will appear here"
                     : "Try adjusting your search or filters")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 120) // Rule: General Coding - Increased padding to push empty state further down
    }
    
    // MARK: - Card View
    // Rule: General Coding - Avoid duplication of code (reusing ContentView card design)
    private func cardView(for entry: ScanEntry) -> some View {
        Button {
            // Rule: General Coding - Add haptic feedback for better UX
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            
            selectedIsLoading = false
            
            let isRecipe = viewModel.isRecipeScan(json: entry.aiResultJSON)
            
            print("[HistoryView] Card tapped. isRecipe=\(isRecipe), hasAIJSON=\(entry.aiResultJSON != nil), isLink=\(entry.recipeURLString != nil)") // Rule: General Coding - Add debug logs
            
            // Rule: State Management - Use item-based sheet presentation for reliable state management
            // Set the entry directly to trigger the appropriate sheet
            if isRecipe {
                recipeEntryToShow = entry
            } else {
                mealEntryToShow = entry
            }
        } label: {
            ZStack(alignment: .bottom) {
                // Base image or placeholder (fallback gray if image missing)
                if let uiImage = historyStore.image(for: entry) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: cardWidth, height: cardHeight)
                        .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: cardWidth, height: cardHeight)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.title)
                                .foregroundStyle(.secondary)
                        )
                }
                
                // Recipe icon badge (top-right corner) - only for recipe scans
                // Rule: General Coding - Optimize for both light AND dark mode
                if viewModel.isRecipeScan(json: entry.aiResultJSON) {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "book.pages.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                                .padding(8)
                                .background(.thinMaterial)
                                .clipShape(Circle())
                                .padding(8)
                        }
                        Spacer()
                    }
                }
                
                // UltraThin material overlay with text (bottom 30% of cardHeight)
                VStack(alignment: .leading, spacing: 2) {
                    // Rule: General Coding - Show recipe description for recipes, carbs/date for meals
                    if viewModel.isRecipeScan(json: entry.aiResultJSON),
                       let recipeDesc = viewModel.getRecipeDescription(from: entry.aiResultJSON) {
                        // Recipe card: show description
                        Text(recipeDesc)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    } else {
                        // Meal card: show carbs and date
                        Text((entry.carbEstimate.components(separatedBy: "·").first?.trimmingCharacters(in: .whitespaces) ?? entry.carbEstimate).replacingOccurrences(of: "carbs", with: "net carbs"))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text(entry.date.formatted(.dateTime.month(.abbreviated).day()))
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(width: cardWidth, height: cardHeight * 0.30, alignment: .leading)
                .background(
                    Color.clear
                        .background(.ultraThinMaterial)
                )
            }
            .frame(width: cardWidth, height: cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// Rule: Testing - Use Preview providers for rapid UI iteration and testing
#Preview {
    HistoryView()
        .environmentObject(ScanHistoryStore())
}

