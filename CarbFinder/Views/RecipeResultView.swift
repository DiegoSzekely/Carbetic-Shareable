import SwiftUI
import SwiftUI
import UIKit
import SafariServices

// MARK: - Data Models for Recipe Results

/// Represents a single ingredient/component in a recipe
struct RecipeComponent: Identifiable, Codable, Hashable {
    let id = UUID()
    var description: String
    var estimatedWeightGrams: Int
    var carbPercentage: Int
    var carbContentGrams: Int

    enum CodingKeys: String, CodingKey { 
        case description, estimatedWeightGrams, carbPercentage, carbContentGrams 
    }
}

/// Represents the parsed AI result for a recipe scan
struct RecipeAIResult: Codable, Hashable {
    var components: [RecipeComponent] // New: ingredient breakdown
    var totalCarbGrams: Int
    var portionsCount: Int // No longer requested from AI, always defaults to 1, kept for backward compatibility
    var confidence: Int
    var recipeDescription: String
    
    // Computed property: carbs per portion (not used in UI, kept for backward compatibility)
    var carbsPerPortion: Double {
        guard portionsCount > 0 else { return 0 }
        return Double(totalCarbGrams) / Double(portionsCount)
    }
}

/// Tolerant raw model for decoding recipe component with alternate key names
private struct RecipeComponentRaw: Decodable {
    var description: String
    var estimatedWeightGrams: Double?
    var carbPercentage: Double?
    var carbContentGrams: Double?

    private enum CodingKeys: String, CodingKey {
        case description
        case estimatedWeightGrams
        case carbPercentage
        case carbContentGrams
        // Alternate keys
        case estimatedWeight
        case weightGrams
        case weight
        case grams
        case carbPercent
        case carbsPercent
        case carb_pct
        case carbGrams
        case netCarbs
        case netCarbGrams
        case carbs
        case carbohydrates
    }

    init(description: String, estimatedWeightGrams: Double?, carbPercentage: Double?, carbContentGrams: Double?) {
        self.description = description
        self.estimatedWeightGrams = estimatedWeightGrams
        self.carbPercentage = carbPercentage
        self.carbContentGrams = carbContentGrams
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Description is required (fall back to empty string)
        self.description = (try? container.decode(String.self, forKey: .description)) ?? ""

        // Weight variants
        var weight: Double? = nil
        if let v = try? container.decode(Double.self, forKey: .estimatedWeightGrams) { weight = v }
        else if let v = try? container.decode(Double.self, forKey: .estimatedWeight) { weight = v }
        else if let v = try? container.decode(Double.self, forKey: .weightGrams) { weight = v }
        else if let v = try? container.decode(Double.self, forKey: .weight) { weight = v }
        else if let v = try? container.decode(Double.self, forKey: .grams) { weight = v }
        self.estimatedWeightGrams = weight

        // Carb percentage variants
        var percent: Double? = nil
        if let v = try? container.decode(Double.self, forKey: .carbPercentage) { percent = v }
        else if let v = try? container.decode(Double.self, forKey: .carbPercent) { percent = v }
        else if let v = try? container.decode(Double.self, forKey: .carbsPercent) { percent = v }
        else if let v = try? container.decode(Double.self, forKey: .carb_pct) { percent = v }
        self.carbPercentage = percent

        // Carb content variants
        var carb: Double? = nil
        if let v = try? container.decode(Double.self, forKey: .carbContentGrams) { carb = v }
        else if let v = try? container.decode(Double.self, forKey: .carbGrams) { carb = v }
        else if let v = try? container.decode(Double.self, forKey: .netCarbs) { carb = v }
        else if let v = try? container.decode(Double.self, forKey: .netCarbGrams) { carb = v }
        else if let v = try? container.decode(Double.self, forKey: .carbs) { carb = v }
        else if let v = try? container.decode(Double.self, forKey: .carbohydrates) { carb = v }
        self.carbContentGrams = carb
    }
}

/// Tolerant raw model for decoding AI response with alternate key names
private struct RecipeAIResultRaw: Decodable {
    var components: [RecipeComponentRaw] // New: component breakdown
    var totalCarbGrams: Double?
    var portionsCount: Double?
    var confidence: Double?
    var recipeDescription: String?
    
    private enum CodingKeys: String, CodingKey {
        case components
        case totalCarbGrams
        case portionsCount
        case confidence
        case recipeDescription
        // Alternate keys
        case items
        case ingredients
        case totalCarbs
        case totalNetCarbs
        case netCarbs
        case portions
        case servings
        case servingCount
        case confidenceScore
        case confidenceLevel
        case description
        case recipeName
        case summary
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Components with alternate keys
        if let arr = try? container.decode([RecipeComponentRaw].self, forKey: .components) {
            self.components = arr
        } else if let arr = try? container.decode([RecipeComponentRaw].self, forKey: .items) {
            self.components = arr
        } else if let arr = try? container.decode([RecipeComponentRaw].self, forKey: .ingredients) {
            self.components = arr
        } else {
            self.components = [] // Gracefully handle missing components for backward compatibility
        }
        
        // Total carbs with alternate keys
        if let v = try? container.decode(Double.self, forKey: .totalCarbGrams) {
            self.totalCarbGrams = v
        } else if let v = try? container.decode(Double.self, forKey: .totalCarbs) {
            self.totalCarbGrams = v
        } else if let v = try? container.decode(Double.self, forKey: .totalNetCarbs) {
            self.totalCarbGrams = v
        } else if let v = try? container.decode(Double.self, forKey: .netCarbs) {
            self.totalCarbGrams = v
        } else {
            self.totalCarbGrams = nil
        }
        
        // Portions count with alternate keys
        if let v = try? container.decode(Double.self, forKey: .portionsCount) {
            self.portionsCount = v
        } else if let v = try? container.decode(Double.self, forKey: .portions) {
            self.portionsCount = v
        } else if let v = try? container.decode(Double.self, forKey: .servings) {
            self.portionsCount = v
        } else if let v = try? container.decode(Double.self, forKey: .servingCount) {
            self.portionsCount = v
        } else {
            self.portionsCount = nil
        }
        
        // Confidence with alternate keys
        if let v = try? container.decode(Double.self, forKey: .confidence) {
            self.confidence = v
        } else if let v = try? container.decode(Double.self, forKey: .confidenceScore) {
            self.confidence = v
        } else if let v = try? container.decode(Double.self, forKey: .confidenceLevel) {
            self.confidence = v
        } else {
            self.confidence = nil
        }
        
        // Description with alternate keys
        if let v = try? container.decode(String.self, forKey: .recipeDescription) {
            self.recipeDescription = v
        } else if let v = try? container.decode(String.self, forKey: .description) {
            self.recipeDescription = v
        } else if let v = try? container.decode(String.self, forKey: .recipeName) {
            self.recipeDescription = v
        } else if let v = try? container.decode(String.self, forKey: .summary) {
            self.recipeDescription = v
        } else {
            self.recipeDescription = nil
        }
    }
}

/// Decodes AI result from JSON text, handling markdown fences and alternate keys
func decodeRecipeAIResult(from text: String?) -> RecipeAIResult? {
    print("[RecipeDecoder] Starting decode with text: \(text ?? "nil")")
    
    guard var raw = text, !raw.isEmpty else {
        print("[RecipeDecoder] ❌ Text is nil or empty")
        return nil
    }
    
    print("[RecipeDecoder] Raw text length: \(raw.count)")
    
    // Strip markdown fences if present
    if raw.hasPrefix("```") {
        print("[RecipeDecoder] Stripping markdown fences")
        raw = raw.replacingOccurrences(of: "```json", with: "")
                 .replacingOccurrences(of: "```", with: "")
    }
    
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    print("[RecipeDecoder] Trimmed text: \(trimmed)")
    
    // Extract JSON object
    let jsonString: String
    if let start = trimmed.firstIndex(of: "{"), let end = trimmed.lastIndex(of: "}") {
        jsonString = String(trimmed[start...end])
        print("[RecipeDecoder] Extracted JSON from braces: \(jsonString)")
    } else {
        jsonString = trimmed
        print("[RecipeDecoder] Using trimmed text as JSON: \(jsonString)")
    }
    
    guard let data = jsonString.data(using: .utf8) else {
        print("[RecipeDecoder] ❌ Failed to convert JSON string to Data")
        return nil
    }
    
    let decoder = JSONDecoder()
    
    // Decode into tolerant raw model
    guard let rawResult = try? decoder.decode(RecipeAIResultRaw.self, from: data) else {
        print("[RecipeDecoder] ❌ Failed to decode JSON into RecipeAIResultRaw")
        print("[RecipeDecoder] JSON that failed to decode: \(jsonString)")
        return nil
    }
    
    print("[RecipeDecoder] ✅ Successfully decoded raw result")
    print("[RecipeDecoder] Raw values - totalCarbs: \(rawResult.totalCarbGrams ?? 0), portions: \(rawResult.portionsCount ?? 1) (default), confidence: \(rawResult.confidence ?? 0), components count: \(rawResult.components.count)")
    
    // Map/round numeric values to Ints for the UI model, computing carb content if missing
    let mappedComponents: [RecipeComponent] = rawResult.components.map { c in
        let weight = c.estimatedWeightGrams ?? 0
        let percent = c.carbPercentage ?? 0
        let carbContent = c.carbContentGrams ?? (weight * percent / 100.0)
        return RecipeComponent(
            description: c.description,
            estimatedWeightGrams: Int(round(weight)),
            carbPercentage: Int(round(percent)),
            carbContentGrams: Int(round(carbContent))
        )
    }
    
    // Fallback total carbs to sum of component carbs if missing (Rule: General Coding - robust fallback)
    let totalCarbs: Int = {
        if let t = rawResult.totalCarbGrams { return Int(round(t)) }
        let sum = mappedComponents.reduce(0) { $0 + $1.carbContentGrams }
        print("[RecipeDecoder] Total carbs missing, computed from components: \(sum)g")
        return sum
    }()
    
    let portions = Int(round(rawResult.portionsCount ?? 1)) // Default to 1 if not provided by AI
    let conf = Int(round(rawResult.confidence ?? 0))
    let desc = rawResult.recipeDescription ?? ""
    
    print("[RecipeDecoder] Final values - totalCarbs: \(totalCarbs), portions: \(portions) (not used by UI), confidence: \(conf), desc: '\(desc)', components: \(mappedComponents.count)")
    
    let result = RecipeAIResult(
        components: mappedComponents,
        totalCarbGrams: totalCarbs,
        portionsCount: portions,
        confidence: conf,
        recipeDescription: desc
    )
    
    print("[RecipeDecoder] ✅ Returning result with \(result.components.count) components")
    return result
}

// MARK: - Recipe Result View

// Preference key for measuring card height
struct CardHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct RecipeResultView: View {
    @Binding var resultText: String?
    @Binding var isLoading: Bool
    var recipeImage: UIImage? = nil // Optional recipe image to display (for camera captures)
    var recipeURL: URL? = nil // Optional recipe URL (for link-based analysis)
    
    @Environment(\.dismiss) var dismiss
    var onDone: (() -> Void)?
    var showHomeInQuickAccessBar: Bool = true
    
    // Rule: State Management - Read Loop integration preference from @AppStorage (default OFF)
    @AppStorage("showLoopIntegration") private var showLoopIntegration: Bool = false
    
    // Local parsed state
    @State private var components: [RecipeComponent] = [] // New: parsed components from AI
    @State private var totalCarbGrams: String = ""
    @State private var portionsCount: String = ""
    @State private var carbsPerPortion: String = ""
    @State private var confidence: String = ""
    @State private var recipeDescription: String = ""
    
    // User-selected meal division
    @State private var selectedMealCount: Int = 1 // How many meals user will divide recipe into
    
    // MARK: - INSULIN DOSING - COMMENTED OUT - START
    // Insulin dosing state
    // @AppStorage("carbRatio") private var carbRatio: Double = 0.0
    // @State private var showingInsulinDosingSheet = false
    // @State private var isEditingCarbRatio: Bool = false
    // @State private var unitsDisplay: String = ""
    // MARK: - INSULIN DOSING - COMMENTED OUT - END
    
    // AI disclaimer sheet
    @State private var showingAIDisclaimerSheet = false
    
    // Recipe image viewer sheet
    @State private var showingRecipeImageSheet = false
    
    // Citation web viewer sheet
    @State private var showingCitationWebView = false
    
    // MARK: - INSULIN DOSING - COMMENTED OUT - START
    // Share sheet state
    // @State private var shareItem: ShareText? = nil
    // 
    // // Identifiable wrapper for item-driven share sheet
    // private struct ShareText: Identifiable {
    //     let id = UUID()
    //     let text: String
    // }
    // 
    // // State to control which detent the insulin sheet should be presented at
    // @State private var sheetDetent: PresentationDetent = .medium
    // MARK: - INSULIN DOSING - COMMENTED OUT - END
    
    // MARK: - INSULIN DOSING - COMMENTED OUT - START
    // Number formatter for displaying carb ratio
    // private let carbRatioDisplayFormatter: NumberFormatter = {
    //     let formatter = NumberFormatter()
    //     formatter.numberStyle = .decimal
    //     formatter.minimumFractionDigits = 1
    //     formatter.maximumFractionDigits = 1
    //     return formatter
    // }()
    // 
    // // Compute formatted insulin units from carbs per selected meal and carb ratio
    // private func computeUnitsDisplay(carbsPerMealString: String, carbRatioValue: Double) -> String {
    //     // Normalize decimal separators and filter invalid characters
    //     let normalizedCarbs = carbsPerMealString.replacingOccurrences(of: ",", with: ".")
    //     
    //     guard let carbs = Double(normalizedCarbs), carbs >= 0,
    //           carbRatioValue > 0 else { return "" } // Check carbRatioValue directly
    //     
    //     let units = carbs / carbRatioValue
    //     let nf = NumberFormatter()
    //     nf.minimumFractionDigits = 0
    //     nf.maximumFractionDigits = 1
    //     nf.numberStyle = .decimal
    //     return nf.string(from: NSNumber(value: units)) ?? ""
    // }
    // 
    // private func buildShareMessage() -> String {
    //     // Start with the recipe description on its own line if available
    //     var lines: [String] = []
    //     if !recipeDescription.isEmpty {
    //         lines.append(recipeDescription)
    //         lines.append("") // blank line separator
    //     }
    //     
    //     // Build confidence label
    //     let confLabel: String
    //     if let confidenceInt = Int(confidence) {
    //         confLabel = confidenceInt > 5 ? "Standard" : "Low"
    //     } else {
    //         confLabel = "—" // Fallback if confidence is not a valid integer
    //     }
    //     
    //     // Carbs per serving display
    //     let carbsDisplay = carbsPerSelectedMeal == "—" ? "—" : carbsPerSelectedMeal
    //     if selectedMealCount == 1 {
    //         lines.append("Total carbs: \(carbsDisplay) g (whole recipe)")
    //     } else {
    //         lines.append("Carbs per serving: \(carbsDisplay) g (whole recipe is \(selectedMealCount) servings)")
    //     }
    //     
    //     // Confidence
    //     lines.append("Confidence: \(confLabel)")
    //     lines.append("") // add a blank line after the confidence line
    //     
    //     // Insulin estimate and carb ratio (only if carb ratio is set and units computed)
    //     if carbRatio > 0.0 && !unitsDisplay.isEmpty {
    //         lines.append("Insulin estimate: \(unitsDisplay) units")
    //         lines.append("With carb ratio of \(carbRatioDisplayFormatter.string(from: NSNumber(value: carbRatio)) ?? String(format: "%.1f", carbRatio)) g/U")
    //     }
    //     
    //     return lines.joined(separator: "\n")
    // }
    // 
    // private struct ActivityView: UIViewControllerRepresentable {
    //     let text: String
    //     
    //     func makeUIViewController(context: Context) -> UIActivityViewController {
    //         UIActivityViewController(activityItems: [text as NSString], applicationActivities: nil)
    //     }
    //     
    //     func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
    // }
    // MARK: - INSULIN DOSING - COMMENTED OUT - END
    
    private var confidenceIcon: (name: String, style: AnyShapeStyle) {
        if let confidenceInt = Int(confidence), confidenceInt < 6 {
            return (name: "exclamationmark.triangle.fill", style: AnyShapeStyle(Color(.systemYellow)))
        } else {
            return (name: "checkmark.seal.fill", style: AnyShapeStyle(.tint))
        }
    }
    
    private var confidenceText: String {
        if let confidenceInt = Int(confidence) {
            return confidenceInt > 5 ? "Standard confidence" : "Low confidence"
        }
        return "—"
    }
    
    // Computed property: carbs per user-selected meal portion
    private var carbsPerSelectedMeal: String {
        guard let totalCarbs = Int(totalCarbGrams), totalCarbs > 0, selectedMealCount > 0 else {
            return "—"
        }
        let carbsPerMeal = Double(totalCarbs) / Double(selectedMealCount)
        return String(format: "%.1f", carbsPerMeal)
    }
    
    private func openLoopApp() {
        guard let url = URL(string: "loop://"), UIApplication.shared.canOpenURL(url) else {
            print("[RecipeResult] Loop app not installed.")
            return
        }
        UIApplication.shared.open(url)
    }
    
    // MARK: - INSULIN DOSING - COMMENTED OUT - START
    // MARK: - Insulin Dosing Sheet View
    // 
    // private var insulinDosingSheetView: some View {
    //     NavigationStack {
    //         ScrollView {
    //             VStack(alignment: .leading, spacing: 0) {
    //                 // Warning text closer to the navigation title
    //                 // Rule: General Coding - Warning message about insulin calculation accuracy
    //                 HStack(alignment: .top, spacing: 8) {
    //                     Image(systemName: "exclamationmark.circle.fill")
    //                         .symbolRenderingMode(.hierarchical)
    //                         .foregroundStyle(AnyShapeStyle(.red))
    //                         .font(.subheadline)
    //                         .padding(.top, 2) // Align icon with first line of text
    //                     
    //                     Text("Insulin estimates are based on AI-generated net-carbs, which may be inaccurate. Do not use for medical decisions/treatment.")
    //                         .font(.subheadline)
    //                         .foregroundStyle(.secondary)
    //                         .fixedSize(horizontal: false, vertical: true)
    //                 }
    //                 .padding(.bottom, 25)
    //                 
    //                 // Carbs per serving row
    //                 HStack(alignment: .firstTextBaseline, spacing: 6) {
    //                     Text(selectedMealCount == 1 ? "Total carbs:" : "Carbs per serving:")
    //                         .font(.body)
    //                         .foregroundStyle(.secondary)
    //                     Text(carbsPerSelectedMeal == "—" ? "— g" : "\(carbsPerSelectedMeal) g")
    //                         .font(.headline).bold()
    //                         .foregroundStyle(.primary)
    //                 }
    //                 .padding(.bottom, 4)
    //                 
    //                 // Servings info (only if selectedMealCount > 1)
    //                 if selectedMealCount > 1 {
    //                     Text("(whole recipe is \(selectedMealCount) servings)")
    //                         .font(.caption)
    //                         .foregroundStyle(.secondary)
    //                         .padding(.bottom, 10)
    //                 } else {
    //                     Text("(whole recipe)")
    //                         .font(.caption)
    //                         .foregroundStyle(.secondary)
    //                         .padding(.bottom, 10)
    //                 }
    //                 
    //                 // Carb ratio row with pencil and inline editor when tapped
    //                 VStack(alignment: .leading, spacing: 10) {
    //                     HStack(spacing: 6) {
    //                         Text("Your carb ratio:")
    //                             .font(.body)
    //                             .foregroundStyle(.secondary)
    //                         
    //                         // Display current carb ratio
    //                         if carbRatio == 0.0 {
    //                             Text("— g/U")
    //                                 .font(.headline).bold()
    //                                 .foregroundStyle(.primary)
    //                         } else {
    //                             Text(carbRatioDisplayFormatter.string(from: NSNumber(value: carbRatio)) ?? String(format: "%.1f", carbRatio))
    //                                 .font(.headline).bold()
    //                                 .foregroundStyle(.primary)
    //                             Text("g/U")
    //                                 .font(.headline).bold()
    //                                 .foregroundStyle(.primary)
    //                         }
    //                         
    //                         Button {
    //                             withAnimation(.easeInOut(duration: 0.2)) {
    //                                 isEditingCarbRatio.toggle()
    //                             }
    //                         } label: {
    //                             Image(systemName: "pencil")
    //                                 .font(.system(size: 15, weight: .semibold))
    //                                 .foregroundStyle(.tint)
    //                                 .padding(6)
    //                                 .background(Color(.systemFill))
    //                                 .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    //                                 .accessibilityLabel("Edit carb ratio")
    //                         }
    //                     }
    //                     
    //                     if isEditingCarbRatio {
    //                         HStack {
    //                             Spacer()
    //                             
    //                             HStack(spacing: 4) {
    //                                 Picker("Carb Ratio", selection: $carbRatio) {
    //                                     ForEach(Array(stride(from:2.0, through: 50.0, by: 0.5)), id: \.self) { ratioValue in
    //                                         Text(String(format: "%.1f", ratioValue))
    //                                             .tag(ratioValue)
    //                                     }
    //                                 }
    //                                 .pickerStyle(.wheel)
    //                                 .labelsHidden()
    //                                 .frame(width: 100)
    //                                 
    //                                 Text("g/U")
    //                                     .font(.headline).bold()
    //                                     .foregroundStyle(.primary)
    //                                     .fixedSize(horizontal: true, vertical: false)
    //                             }
    //                             .padding(.trailing, 20)
    //                             
    //                             Button("Save") {
    //                                 withAnimation(.easeInOut(duration: 0.2)) { isEditingCarbRatio = false }
    //                                 unitsDisplay = computeUnitsDisplay(carbsPerMealString: carbsPerSelectedMeal, carbRatioValue: carbRatio)
    //                                 print("[RecipeResult] Carb ratio editing done. Updated unitsDisplay=\(unitsDisplay)")
    //                             }
    //                             .buttonStyle(.borderedProminent)
    //                             .font(.body)
    //                             .id("saveButton") // Rule: General Coding - Updated id to match new button text
    //                             
    //                             Spacer()
    //                         }
    //                         .padding(.top, 10)
    //                     }
    //                 }
    //                 .padding(.bottom, 15)
    //                 
    //                 Divider()
    //                     .padding(.bottom, 10)
    //                 
    //                 // Unit estimate caption and value
    //                 VStack(alignment: .leading, spacing: 4) {
    //                     Text("Insulin estimate")
    //                         .font(.subheadline)
    //                         .foregroundStyle(.secondary)
    //                     if unitsDisplay.isEmpty {
    //                         Text("—")
    //                             .font(.title3).bold()
    //                             .foregroundStyle(.secondary)
    //                             .accessibilityLabel("Units not available")
    //                     } else {
    //                         HStack(alignment: .firstTextBaseline, spacing: 4) {
    //                             Text(unitsDisplay)
    //                                 .font(.title).bold()
    //                             Text("units")
    //                                 .font(.headline)
    //                                 .foregroundStyle(.secondary)
    //                         }
    //                         .accessibilityElement(children: .combine)
    //                         .accessibilityLabel("Units \(unitsDisplay)")
    //                     }
    //                 }
    //                 
    //                 if carbRatio == 0.0 {
    //                     HStack(alignment: .top, spacing: 6) {
    //                         Image(systemName: "info.circle.fill")
    //                             .font(.caption)
    //                             .foregroundStyle(.secondary)
    //                         Text("Enter your grams-per-unit carb ratio to calculate insulin units from the detected carbohydrates.")
    //                             .font(.subheadline)
    //                             .foregroundStyle(.secondary)
    //                     }
    //                     .padding(.top, 10)
    //                 }
    //                 
    //                 Spacer(minLength: 20)
    //                 
    //                 // Share functionality is shown only after a valid carb ratio is selected
    //                 if carbRatio > 0.0 {
    //                     Button {
    //                         // Always recalculate unitsDisplay fresh when share is pressed
    //                         unitsDisplay = computeUnitsDisplay(carbsPerMealString: carbsPerSelectedMeal, carbRatioValue: carbRatio)
    //                         print("[RecipeResult] Share tapped. Recomputed unitsDisplay=\(unitsDisplay)")
    //                         
    //                         // Build and sanitize message, ensure non-empty fallback
    //                         let raw = buildShareMessage().trimmingCharacters(in: .whitespacesAndNewlines)
    //                         let message: String
    //                         if raw.isEmpty {
    //                             let carbsDisplay = carbsPerSelectedMeal == "—" ? "—" : carbsPerSelectedMeal
    //                             let confLabel = (Int(confidence) ?? 0) > 5 ? "Standard" : (Int(confidence) == nil ? "—" : "Low")
    //                             let servingInfo = selectedMealCount == 1 ? "(whole recipe)" : "(whole recipe is \(selectedMealCount) servings)"
    //                             let unitsPart = unitsDisplay.isEmpty ? "" : "\nInsulin estimate: \(unitsDisplay) units"
    //                             message = "Carbs per serving: \(carbsDisplay) g \(servingInfo)\nConfidence: \(confLabel)\n\n\(unitsPart)".trimmingCharacters(in: .whitespacesAndNewlines)
    //                             print("[RecipeResult] Share message built from fallback. Length=\(message.count)")
    //                         } else {
    //                             message = raw
    //                             print("[RecipeResult] Share message built from recipe description. Length=\(message.count)")
    //                         }
    //                         
    //                         // Present item-driven sheet to avoid race where the sheet reads stale (empty) text
    //                         shareItem = ShareText(text: message)
    //                         print("[RecipeResult] shareItem set. isNil=\(shareItem == nil)")
    //                     } label: {
    //                         HStack {
    //                             Image(systemName: "square.and.arrow.up")
    //                                 .font(.headline)
    //                             Text("Share Results")
    //                                 .font(.headline)
    //                         }
    //                         .frame(maxWidth: .infinity)
    //                         .padding()
    //                         .background(Color.accentColor)
    //                         .foregroundColor(.white)
    //                         .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    //                     }
    //                     .onAppear {
    //                         // Ensure unitsDisplay is recalculated when share button appears
    //                         unitsDisplay = computeUnitsDisplay(carbsPerMealString: carbsPerSelectedMeal, carbRatioValue: carbRatio)
    //                         print("[RecipeResult] Share button appeared. unitsDisplay=\(unitsDisplay)")
    //                     }
    //                 }
    //             }
    //             .padding(.top, 0) // Reduced top padding to bring content closer to navigation title
    //             .padding(.horizontal)
    //             .padding(.bottom)
    //         }
    //         .navigationTitle("Insulin Dosing")
    //         .navigationBarTitleDisplayMode(.large)
    //         .toolbar {
    //             ToolbarItem(placement: .navigationBarTrailing) {
    //                 Button("Done") {
    //                     showingInsulinDosingSheet = false
    //                 }
    //             }
    //         }
    //     }
    //     // Use item-driven sheet to avoid showing empty share sheet the first time, as state is updated only after sheet is presented
    //     .sheet(item: $shareItem) { item in
    //         ActivityView(text: item.text)
    //     }
    // }
    // MARK: - INSULIN DOSING - COMMENTED OUT - END
    
    private func developerJSONString() -> String {
        // Serialize from the current parsed/edited state so the JSON reflects what the UI shows (Rule: General Coding - include components)
        let recipe = RecipeAIResult(
            components: components,
            totalCarbGrams: Int(totalCarbGrams) ?? 0,
            portionsCount: Int(portionsCount) ?? 1,
            confidence: Int(confidence) ?? 0,
            recipeDescription: recipeDescription
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        if let data = try? encoder.encode(recipe), let str = String(data: data, encoding: .utf8) {
            return str
        }
        
        // Fallback to the raw resultText if encoding fails for any reason
        return resultText ?? "{}"
    }
    
    private var hasRenderableData: Bool {
        return !components.isEmpty || !totalCarbGrams.isEmpty || !recipeDescription.isEmpty || (resultText?.isEmpty == false)
    }
    
    var body: some View {
        Group {
            if isLoading && !hasRenderableData {
                VStack(spacing: 12) {
                    ProgressView("Analyzing recipe...")
                    if let resultText, resultText.isEmpty == false {
                        Text(resultText)
                            .font(.footnote.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Form {
                    summaryAndConfidenceSection
                    
                    // Bottom spacing for quick-access bar
                    Section {
                        Spacer()
                            .frame(height: 30)
                    }
                    .listRowBackground(EmptyView())
                    .listRowSeparator(.hidden)
                }
                .listSectionSpacing(0)
            }
        }
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.large) // Rule: Apple Design Guidelines - Large title that collapses into nav bar when scrolling
        .navigationBarBackButtonHidden(true) // Rule: Visual Design - Removed Done button for cleaner UI, navigation handled by quick access bar
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                // Rule: General Coding - Button placement in navigation bar for quick access to recipe, icon changes dynamically
                Button {
                    if let url = recipeURL {
                        // Open URL in Safari
                        print("[RecipeResult] Open recipe URL button tapped from nav bar: \(url.absoluteString)")
                        UIApplication.shared.open(url)
                    } else {
                        // Show recipe image
                        print("[RecipeResult] View recipe image button tapped from nav bar. hasImage=\(recipeImage != nil)")
                        showingRecipeImageSheet = true
                    }
                } label: {
                    Image(systemName: recipeURL != nil ? "arrow.up.right.square" : "text.page")
                }
                .accessibilityLabel(recipeURL != nil ? "Open recipe in browser" : "View recipe image")
            }
        }
        .onChange(of: resultText) { _, newValue in
            if let parsed = decodeRecipeAIResult(from: newValue) {
                components = parsed.components // Rule: State Management - populate components array
                totalCarbGrams = String(parsed.totalCarbGrams)
                portionsCount = String(parsed.portionsCount)
                carbsPerPortion = String(format: "%.1f", parsed.carbsPerPortion)
                confidence = String(parsed.confidence)
                recipeDescription = parsed.recipeDescription
                print("[RecipeResult] Parsed: \(parsed.totalCarbGrams)g, \(parsed.portionsCount) portions, conf: \(parsed.confidence), components: \(parsed.components.count)")
                // MARK: - INSULIN DOSING - COMMENTED OUT - START
                // Recalculate insulin units when result changes
                // unitsDisplay = computeUnitsDisplay(carbsPerMealString: carbsPerSelectedMeal, carbRatioValue: carbRatio)
                // MARK: - INSULIN DOSING - COMMENTED OUT - END
            }
        }
        // MARK: - INSULIN DOSING - COMMENTED OUT - START
        // .onChange(of: selectedMealCount) { _, _ in
        //     // Recalculate insulin units when meal count changes
        //     unitsDisplay = computeUnitsDisplay(carbsPerMealString: carbsPerSelectedMeal, carbRatioValue: carbRatio)
        //     print("[RecipeResult] Meal count changed to \(selectedMealCount). Updated unitsDisplay=\(unitsDisplay)")
        // }
        // .onChange(of: carbRatio) { _, newValue in
        //     // Recalculate insulin units when carb ratio changes
        //     unitsDisplay = computeUnitsDisplay(carbsPerMealString: carbsPerSelectedMeal, carbRatioValue: newValue)
        //     print("[RecipeResult] Carb ratio changed to \(newValue). Updated unitsDisplay=\(unitsDisplay)")
        // }
        // MARK: - INSULIN DOSING - COMMENTED OUT - END
        .onAppear {
            if let parsed = decodeRecipeAIResult(from: resultText) {
                components = parsed.components // Rule: State Management - populate components array
                totalCarbGrams = String(parsed.totalCarbGrams)
                portionsCount = String(parsed.portionsCount)
                carbsPerPortion = String(format: "%.1f", parsed.carbsPerPortion)
                confidence = String(parsed.confidence)
                recipeDescription = parsed.recipeDescription
            }
            // MARK: - INSULIN DOSING - COMMENTED OUT - START
            // Calculate initial insulin units
            // unitsDisplay = computeUnitsDisplay(carbsPerMealString: carbsPerSelectedMeal, carbRatioValue: carbRatio)
            // print("[RecipeResult] View appeared. Initial unitsDisplay=\(unitsDisplay), components=\(components.count)")
            // MARK: - INSULIN DOSING - COMMENTED OUT - END
        }
        .overlay(alignment: .bottom) {
            // MARK: - INSULIN DOSING - COMMENTED OUT - START
            // Only show quick-access bar if there's something to show
            // When Loop integration is OFF and we're in history (showHomeInQuickAccessBar == false), hide the bar
            if showLoopIntegration || showHomeInQuickAccessBar {
                quickAccessBar
            }
            // MARK: - INSULIN DOSING - COMMENTED OUT - END
        }
        .sheet(isPresented: $showingAIDisclaimerSheet) {
            DisclaimerView(onAccept: {
                // When user accepts disclaimer, just dismiss the sheet
                showingAIDisclaimerSheet = false
            })
                .interactiveDismissDisabled(true) // Prevent swipe-to-dismiss - user must scroll, check, and continue
        }
        .sheet(isPresented: $showingRecipeImageSheet) {
            RecipeImageViewerSheet(image: recipeImage)
                .interactiveDismissDisabled(true) // Rule: Apple Design Guidelines - Prevent swipe-to-dismiss, force explicit Done button
                .presentationDragIndicator(.hidden) // Rule: Visual Design - Hide drag indicator since sheet is not dismissible by drag
        }
        .sheet(isPresented: $showingCitationWebView) {
            // Rule: General Coding - Safari view for citation link (same pattern as PlanView)
            if let url = URL(string: "https://www.eurofir.org/wp-admin/wp-content/uploads/2015/12/EUROFIR-RECIPE-GUIDELINE_FINAL.pdf?utm_source=chatgpt.com") {
                SafariView(url: url)
            }
        }
        // MARK: - INSULIN DOSING - COMMENTED OUT - START
        // .sheet(isPresented: $showingInsulinDosingSheet) {
        //     insulinDosingSheetView
        //         .presentationDetents([.medium, .large], selection: $sheetDetent)
        //         .onChange(of: isEditingCarbRatio) { _, newValue in
        //             // When editing carb ratio, expand to large detent
        //             withAnimation(.easeInOut(duration: 0.3)) {
        //                 sheetDetent = newValue ? .large : .medium
        //             }
        //         }
        //         .onAppear {
        //             // Reset to medium when sheet appears
        //             sheetDetent = .medium
        //             // Ensure unitsDisplay is calculated when sheet appears
        //             unitsDisplay = computeUnitsDisplay(carbsPerMealString: carbsPerSelectedMeal, carbRatioValue: carbRatio)
        //             print("[RecipeResult] Insulin sheet appeared. unitsDisplay=\(unitsDisplay), carbRatio=\(carbRatio)")
        //         }
        // }
        // MARK: - INSULIN DOSING - COMMENTED OUT - END
    }
    
    // MARK: - Summary Section
    
    private var summaryAndConfidenceSection: some View {
        Section(
            content: {
                VStack(spacing: 14) { // Rule: Apple Design Guidelines - Increased spacing for better visual separation
                if !recipeDescription.isEmpty {
                    Text(recipeDescription)
                        .font(.title2) 
                        .fontWeight(.regular) // Rule: Visual Design - Changed from .semibold to .regular for lighter appearance
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 0)
                        .padding(.bottom, 0)
                }
                
                // Total Net Carbs & Confidence Card
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.secondary.opacity(0))
                            Image(systemName: confidenceIcon.name)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(confidenceIcon.style)
                                .font(.system(size: 42, weight: .semibold))
                        }
                        .frame(width: 56, height: 56)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            (Text(totalCarbGrams.isEmpty ? "— g" : "\(totalCarbGrams) g").fontWeight(.bold) +
                             Text(totalCarbGrams.isEmpty ? "" : " of net carbs").foregroundStyle(.secondary))
                                .font(.title)
                            Text("in whole recipe (no multipliers)")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.bottom, 12)
                    
                    // AI Disclaimer section, now fully tappable (icon + text)
                    VStack(alignment: .leading, spacing: 0) {
                        Divider()
                        Button { // Make the entire disclaimer (icon + text) clickable
                            showingAIDisclaimerSheet = true
                        } label: {
                            HStack(alignment: .top, spacing: 5) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(AnyShapeStyle(.red))
                                    .font(.callout)
                                Text("Analysis is AI generated and might be innacurate. Click for more information.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(5)
                            }
                            .contentShape(Rectangle()) // Make entire HStack tappable
                        }
                        .buttonStyle(.plain) // Remove default button styling
                        .padding(.top, 12)
                    }
                    .padding(.leading, 56 + 12)
                }
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
                .padding(.bottom, 15) // Rule: Layout Spacing - Standard bottom padding
                
                // Meal Division Calculator Section
                VStack(alignment: .leading, spacing: 16) {
                    // Question text
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Into how many servings will you divide this recipe?")
                            .font(.headline) // Rule: Visual Design - Increased from .callout to .title3 for better prominence
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Button bar with meal count options (including 1)
                    HStack(spacing: 0) {
                        ForEach([1, 2, 3, 4, 5, 6], id: \.self) { count in
                            Button {
                                print("[RecipeResult] Selected meal count: \(count)")
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedMealCount = count
                                }
                            } label: {
                                Text("\(count)")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundStyle(selectedMealCount == count ? .white : .primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(selectedMealCount == count ? Color.blue : Color.clear)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            
                            // Add divider between buttons (except after last)
                            if count != 6 {
                                Divider()
                                    .frame(height: 32)
                            }
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color(UIColor.separator), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    
                    // Result display
                    if selectedMealCount > 0 {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(selectedMealCount == 1 ? "Total carbs" : "Carbs per serving")
                                .font(.subheadline) // Rule: Visual Design - Increased from .caption to .subheadline for better readability
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(carbsPerSelectedMeal)
                                    .font(.title)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                Text("g")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if selectedMealCount > 1 {
                                    Text("÷ \(selectedMealCount) servings")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("(whole recipe)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(UIColor.systemGroupedBackground)) // Rule: Visual Design - Changed to systemGroupedBackground for screen background color
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(16) // Rule: Layout Spacing - Inner padding for content
                .background(Color(UIColor.secondarySystemGroupedBackground)) // Rule: Visual Design - Added adaptive white background matching total carbs card
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous)) // Rule: Visual Design - Rounded corners matching total carbs card
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2) // Rule: Visual Design - Subtle shadow matching total carbs card
                
                // Component Breakdown Section (Rule: No Duplication - reuse ResultView's component display pattern)
                if !components.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        // Title
                        HStack {
                            Text("Breakdown of ingredients")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            Spacer()
                        }

                        // Components list
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(components.indices, id: \.self) { index in
                                let component = components[index]
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(component.description)
                                        .font(.headline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary.opacity(0.85))
                                    
                                    HStack(spacing: 24) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Weight")
                                                .font(.caption)
                                                .foregroundStyle(.secondary.opacity(0.8))
                                            Text("\(component.estimatedWeightGrams) g")
                                                .font(.body)
                                                .fontWeight(.regular)
                                                .foregroundStyle(.primary.opacity(0.75))
                                        }

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Carb %")
                                                .font(.caption)
                                                .foregroundStyle(.secondary.opacity(0.8))
                                            Text("\(component.carbPercentage)%")
                                                .font(.body)
                                                .fontWeight(.regular)
                                                .foregroundStyle(.primary.opacity(0.75))
                                        }

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Net carbs")
                                                .font(.caption)
                                                .foregroundStyle(.secondary.opacity(0.8))
                                            Text("\(component.carbContentGrams) g")
                                                .font(.body)
                                                .fontWeight(.regular)
                                                .foregroundStyle(.primary.opacity(0.75))
                                        }
                                        Spacer()
                                    }
                                }
                                .padding(.vertical, 16)
                                
                                if index < components.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                    .padding(16) // Rule: Layout Spacing - Inner padding for content
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous) // Rule: Visual Design - Border with rounded corners matching other cards
                            .strokeBorder(Color(UIColor.separator).opacity(0.7), lineWidth: 1.5) // Rule: Visual Design - Consistent border style
                    )
                    .padding(.top, 16) // Rule: Layout Spacing - Space from meal division section above
                }
            }
            .listRowInsets(EdgeInsets())
        },
            footer: {
                VStack(alignment: .leading, spacing: 8) {
                    // Citation link - clickable text with info icon
                    Button {
                        print("[RecipeResult] Citation link tapped - opening web view")
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showingCitationWebView = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                                .font(.caption)
                            Text("Learn how carbs are counted (Citation)")
                                .font(.caption)
                        }
                        .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    
                    // Developer view JSON disclosure
                    DisclosureGroup {
                        ScrollView {
                            Text(developerJSONString())
                                .font(.footnote.monospaced())
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                        }
                        .frame(minHeight: 130)
                    } label: {
                        Text("Developer view (JSON)")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
            }
        )
        .listRowBackground(EmptyView())
        .listRowSeparator(.hidden)
    }
    
    // MARK: - Quick Access Bar (Apple-style Menu Bar)
    
    private var quickAccessBar: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Apple-style menu bar at the bottom
            HStack(spacing: 0) {
                // Loop app button - conditionally shown based on user preference
                // Rule: General Coding - Respect user preference for Loop integration
                if showLoopIntegration {
                    Button(action: openLoopApp) {
                        VStack(spacing: 5) { // Rule: Layout Spacing - Increased from 4 to 5 for better proportions with larger icons
                            Image("looplogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32) // Rule: Visual Design - Increased from 28 to 32 for more prominent icons
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous)) // Rule: Visual Design - Slightly larger corner radius to match larger size
                            Text("Loop")
                                .font(.caption) // Rule: Visual Design - Increased from .caption2 to .caption for better readability
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain) // Rule: Apple Design Guidelines - Plain button style for menu bar items
                    .foregroundStyle(.primary)
                }
                
                // MARK: - INSULIN DOSING - COMMENTED OUT - START
                // Insulin dosing button
                // Button(action: { showingInsulinDosingSheet = true }) {
                //     VStack(spacing: 5) { // Rule: Layout Spacing - Increased from 4 to 5 for better proportions with larger icons
                //         Image(systemName: "cross.vial")
                //             .font(.system(size: 27, weight: .regular)) // Rule: Visual Design - Increased from 24 to 27 for more prominent icons
                //             .frame(height: 32) // Rule: Visual Design - Increased from 28 to 32 to match Loop icon height
                //         Text("Insulin Dosing")
                //             .font(.caption) // Rule: Visual Design - Increased from .caption2 to .caption for better readability
                //             .lineLimit(1)
                //     }
                //     .frame(maxWidth: .infinity)
                //     .contentShape(Rectangle())
                // }
                // .buttonStyle(.plain)
                // .foregroundStyle(.primary)
                // MARK: - INSULIN DOSING - COMMENTED OUT - END
                
                // Home button
                if showHomeInQuickAccessBar {
                    Button(action: {
                        if let onDone = onDone {
                            onDone()
                        } else {
                            dismiss()
                        }
                    }) {
                        VStack(spacing: 5) { // Rule: Layout Spacing - Increased from 4 to 5 for better proportions with larger icons
                            Image(systemName: "house")
                                .font(.system(size: 27, weight: .regular)) // Rule: Visual Design - Increased from 24 to 27 for more prominent icons
                                .frame(height: 32) // Rule: Visual Design - Increased from 28 to 32 to match Loop icon height
                            Text("Home")
                                .font(.caption) // Rule: Visual Design - Increased from .caption2 to .caption for better readability
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 8) // Rule: Apple Design Guidelines - Standard horizontal padding for menu bar
            .padding(.top, 14) // Rule: Layout Spacing - Increased from 10 to 14 for slightly more breathing room above icons
            .padding(.bottom, 0) // Rule: Layout Spacing - Zero padding, rely on safe area for bottom spacing
            .background {
                // Rule: Apple Design Guidelines - ultraThinMaterial background with prominent top border, extends into safe area with same material
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(Color(UIColor.separator).opacity(0.7))
                            .frame(height: 0.5)
                    }
                    .ignoresSafeArea(edges: .bottom) // Rule: Visual Design - Extend material into safe area for cohesive appearance
            }
            .accessibilityIdentifier("quick-access-bar")
        }
    }
}

// MARK: - Recipe Image Viewer Sheet

/// Full-screen sheet for viewing and zooming the recipe image
struct RecipeImageViewerSheet: View {
    let image: UIImage?
    @Environment(\.dismiss) var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    // Rule: Performance Optimization - Smooth scaling
                                    scale = lastScale * value
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                    // Limit minimum scale to 1.0
                                    if scale < 1.0 {
                                        withAnimation(.spring(response: 0.3)) {
                                            scale = 1.0
                                            lastScale = 1.0
                                        }
                                    }
                                    // Limit maximum scale to 5.0
                                    if scale > 5.0 {
                                        withAnimation(.spring(response: 0.3)) {
                                            scale = 5.0
                                            lastScale = 5.0
                                        }
                                    }
                                }
                        )
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    // Only allow panning when zoomed in
                                    if scale > 1.0 {
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                    // Reset offset when scale returns to 1.0
                                    if scale <= 1.0 {
                                        withAnimation(.spring(response: 0.3)) {
                                            offset = .zero
                                            lastOffset = .zero
                                        }
                                    }
                                }
                        )
                        .onTapGesture(count: 2) {
                            // Double-tap to zoom in/out
                            withAnimation(.spring(response: 0.3)) {
                                if scale > 1.0 {
                                    scale = 1.0
                                    lastScale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = 2.5
                                    lastScale = 2.5
                                }
                            }
                        }
                        .accessibilityLabel("Recipe image")
                        .accessibilityHint("Double tap to zoom, pinch to zoom, drag to pan")
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "photo")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("Image not available")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Recipe Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        print("[RecipeImageViewer] Done tapped")
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.8), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

// MARK: - Safari View Wrapper
// Note: SafariView is defined in PlanView.swift to avoid duplication (Rule: No Duplication)

// MARK: - Preview

#Preview("Recipe Result") {
    @Previewable @State var text: String? = """
{
  "components": [
    {"description": "All-purpose flour", "estimatedWeightGrams": 280, "carbPercentage": 76, "carbContentGrams": 213},
    {"description": "Granulated sugar", "estimatedWeightGrams": 200, "carbPercentage": 100, "carbContentGrams": 200},
    {"description": "Brown sugar", "estimatedWeightGrams": 100, "carbPercentage": 98, "carbContentGrams": 98},
    {"description": "Chocolate chips", "estimatedWeightGrams": 340, "carbPercentage": 59, "carbContentGrams": 201}
  ],
  "totalCarbGrams": 712,
  "confidence": 7,
  "recipeDescription": "Chocolate chip cookies"
}
"""
    @Previewable @State var loading = false
    return NavigationStack {
        RecipeResultView(
            resultText: $text,
            isLoading: $loading,
            onDone: { print("Preview done tapped") }
        )
    }
}
