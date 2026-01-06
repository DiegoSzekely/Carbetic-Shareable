import SwiftUI
import UIKit // Added for Color(.systemYellow)

// Helper models with unique names to avoid collisions
struct MealComponentV2: Identifiable, Codable, Hashable {
    let id = UUID()
    var description: String
    var estimatedWeightGrams: Int
    var carbPercentage: Int
    var carbContentGrams: Int

    enum CodingKeys: String, CodingKey { case description, estimatedWeightGrams, carbPercentage, carbContentGrams }
}

struct AIResultV2: Codable, Hashable {
    var components: [MealComponentV2]
    var totalCarbGrams: Int
    var confidence: Int
    var mealSummary: String
}

private struct MealComponentRaw: Decodable {
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

private struct AIResultRaw: Decodable {
    var components: [MealComponentRaw]
    var totalCarbGrams: Double?
    var confidence: Double?
    var mealSummary: String?

    private enum CodingKeys: String, CodingKey {
        case components
        case totalCarbGrams
        case confidence
        case mealSummary
        // Alternate keys
        case items
        case ingredients
        case totalCarbs
        case totalNetCarbs
        case netCarbs
        case confidenceScore
        case confidenceLevel
        case summary
        case mealDescription
        case description
    }

    init(components: [MealComponentRaw], totalCarbGrams: Double?, confidence: Double?, mealSummary: String?) {
        self.components = components
        self.totalCarbGrams = totalCarbGrams
        self.confidence = confidence
        self.mealSummary = mealSummary
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Components with alternate keys
        if let arr = try? container.decode([MealComponentRaw].self, forKey: .components) {
            self.components = arr
        } else if let arr = try? container.decode([MealComponentRaw].self, forKey: .items) {
            self.components = arr
        } else if let arr = try? container.decode([MealComponentRaw].self, forKey: .ingredients) {
            self.components = arr
        } else {
            self.components = []
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

        // Summary with alternate keys
        if let v = try? container.decode(String.self, forKey: .mealSummary) {
            self.mealSummary = v
        } else if let v = try? container.decode(String.self, forKey: .summary) {
            self.mealSummary = v
        } else if let v = try? container.decode(String.self, forKey: .mealDescription) {
            self.mealSummary = v
        } else if let v = try? container.decode(String.self, forKey: .description) {
            self.mealSummary = v
        } else {
            self.mealSummary = nil
        }
    }
}

private func decodeAIResultV2(from text: String?) -> AIResultV2? {
    guard var raw = text, !raw.isEmpty else { return nil }
    // Strip common markdown fences if present
    if raw.hasPrefix("```") {
        raw = raw.replacingOccurrences(of: "```json", with: "")
                 .replacingOccurrences(of: "```", with: "")
    }
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let jsonString: String
    if let start = trimmed.firstIndex(of: "{"), let end = trimmed.lastIndex(of: "}") {
        jsonString = String(trimmed[start...end])
    } else {
        jsonString = trimmed
    }
    guard let data = jsonString.data(using: .utf8) else { return nil }
    let decoder = JSONDecoder()
    // First decode into the tolerant raw model
    guard let rawResult = try? decoder.decode(AIResultRaw.self, from: data) else { return nil }

    // Map/round numeric values to Ints for the UI model, computing carb content if missing
    let mappedComponents: [MealComponentV2] = rawResult.components.map { c in
        let weight = c.estimatedWeightGrams ?? 0
        let percent = c.carbPercentage ?? 0
        let carbContent = c.carbContentGrams ?? (weight * percent / 100.0)
        return MealComponentV2(
            description: c.description,
            estimatedWeightGrams: Int(round(weight)),
            carbPercentage: Int(round(percent)),
            carbContentGrams: Int(round(carbContent))
        )
    }

    // Fallback total carbs to sum of component carbs if missing
    let totalCarbsValue: Int = {
        if let t = rawResult.totalCarbGrams { return Int(round(t)) }
        let sum = mappedComponents.reduce(0) { $0 + $1.carbContentGrams }
        return sum
    }()

    let confidenceValue: Int = Int(round(rawResult.confidence ?? 0))
    let summaryValue: String = rawResult.mealSummary ?? ""

    return AIResultV2(
        components: mappedComponents,
        totalCarbGrams: totalCarbsValue,
        confidence: confidenceValue,
        mealSummary: summaryValue
    )
}

// MARK: ResultView is now the target of navigation after Capture3 and is bound to ContentView's ai state
struct ResultView: View {
    @Binding var resultText: String?
    @Binding var isLoading: Bool

    // Use @Environment(\.dismiss) to programmatically dismiss the view
    @Environment(\.dismiss) var dismiss

    // New optional callback for custom "Done" behavior
    var onDone: (() -> Void)?
    
    // Controls whether the Home item appears in the quick-access bar (hide it for history sheet)
    var showHomeInQuickAccessBar: Bool = true

    // Rule: State Management - Read Loop integration preference from @AppStorage (default OFF)
    @AppStorage("showLoopIntegration") private var showLoopIntegration: Bool = false

    // Local editable state derived from parsed JSON
    @State private var components: [MealComponentV2] = []
    @State private var totalCarbGrams: String = ""
    @State private var confidence: String = ""
    @State private var mealSummary: String = ""

    // MARK: - INSULIN DOSING - COMMENTED OUT - START
    // Persistent carb ratio (grams per unit), editable by user and reused next time
    // @AppStorage("carbRatio") private var carbRatio: Double = 0.0 // Changed to Double, default to 0.0

    // Local state for editing and displaying insulin units
    // @State private var isEditingCarbRatio: Bool = false
    // @State private var unitsDisplay: String = ""

    // State to control the presentation of the insulin dosing sheet
    // @State private var showingInsulinDosingSheet = false
    // MARK: - INSULIN DOSING - COMMENTED OUT - END

    // State to control the presentation of the AI disclaimer sheet
    @State private var showingAIDisclaimerSheet = false
    
    // Citation web viewer sheet
    @State private var showingCitationWebView = false
    
    // MARK: - INSULIN DOSING - COMMENTED OUT - START
    // State to control which detent the sheet should be presented at
    // @State private var sheetDetent: PresentationDetent = .medium
    // MARK: - INSULIN DOSING - COMMENTED OUT - END

    // MARK: - INSULIN DOSING - COMMENTED OUT - START
    // Replace separate share state with single item-driven optional for share sheet
    // @State private var shareItem: ShareText? = nil
    // MARK: - INSULIN DOSING - COMMENTED OUT - END

    // MARK: - INSULIN DOSING - COMMENTED OUT - START
    // Identifiable wrapper for item-driven share sheet
    // private struct ShareText: Identifiable {
    //     let id = UUID()
    //     let text: String
    // }
    // MARK: - INSULIN DOSING - COMMENTED OUT - END

    // Custom NumberFormatters for displaying units
    private let weightFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.positiveSuffix = " g"
        formatter.allowsFloats = false
        return formatter
    }()

    private let percentageFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.positiveSuffix = " %"
        formatter.allowsFloats = false
        return formatter
    }()

    private let carbContentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.positiveSuffix = " g"
        formatter.allowsFloats = false
        return formatter
    }()

    // Number formatter for displaying carb ratio
    private let carbRatioDisplayFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    // MARK: - INSULIN DOSING - COMMENTED OUT - START
    // Compute formatted insulin units from total carbs string and carb ratio double
    // private func computeUnitsDisplay(totalCarbsString: String, carbRatioValue: Double) -> String {
    //     // Normalize decimal separators and filter invalid characters
    //     let normalizedCarbs = totalCarbsString.replacingOccurrences(of: ",", with: ".")
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
    // MARK: - INSULIN DOSING - COMMENTED OUT - END

    private var confidenceIcon: (name: String, style: AnyShapeStyle) {
        if let confidenceInt = Int(confidence), confidenceInt < 6 {
            return (name: "exclamationmark.triangle.fill", style: AnyShapeStyle(Color(.systemYellow))) // Changed to use systemYellow
        } else {
            return (name: "checkmark.seal.fill", style: AnyShapeStyle(.tint))
        }
    }

    private var confidenceText: String {
        if let confidenceInt = Int(confidence) {
            return confidenceInt > 5 ? "Standard confidence" : "Low confidence"
        }
        return "—" // Fallback if confidence is empty or not a valid integer
    }

    // MARK: - INSULIN DOSING - COMMENTED OUT - START
    // private func buildShareMessage() -> String {
    //     // Start with the meal summary on its own line if available
    //     var lines: [String] = []
    //     if !mealSummary.isEmpty {
    //         lines.append(mealSummary)
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
    //     // Total net carbs
    //     let carbsDisplay = totalCarbGrams.isEmpty ? "—" : totalCarbGrams
    //     lines.append("Total net carbs: \(carbsDisplay) g")
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

    private func openLoopApp() {
        guard let url = URL(string: "loop://"), UIApplication.shared.canOpenURL(url) else {
            // The Loop app is not installed.
            // You could optionally show an alert to the user here.
            print("Loop app not installed.")
            return
        }
        UIApplication.shared.open(url)
    }
    
    private func developerJSONString() -> String {
        // Always serialize from the current parsed/edited state so the JSON reflects what the UI shows
        let ai = AIResultV2(
            components: components,
            totalCarbGrams: Int(Double(totalCarbGrams) ?? 0),
            confidence: Int(Double(confidence) ?? 0),
            mealSummary: mealSummary
        )
        if let data = try? JSONEncoder().encode(ai), let str = String(data: data, encoding: .utf8) {
            return str
        }
        // Fallback to the raw resultText if encoding fails for any reason
        return resultText ?? ""
    }

    // MARK: - Private Helper Views (Rules Applied: General Coding, SwiftUI-specific Patterns)
    
    // MARK: - INSULIN DOSING - COMMENTED OUT - START
    // Insulin Dosing Sheet View
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
    //                 // Total carbs row
    //                 HStack(alignment: .firstTextBaseline, spacing: 6) {
    //                     Text("Total carbs:")
    //                         .font(.body)
    //                         .foregroundStyle(.secondary)
    //                     Text(totalCarbGrams.isEmpty ? "— g" : "\(totalCarbGrams) g")
    //                         .font(.headline).bold()
    //                         .foregroundStyle(.primary)
    //                 }
    //                 .padding(.bottom, 10)
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
    //                                 unitsDisplay = computeUnitsDisplay(totalCarbsString: totalCarbGrams, carbRatioValue: carbRatio)
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
    //                         unitsDisplay = computeUnitsDisplay(totalCarbsString: totalCarbGrams, carbRatioValue: carbRatio)
    //                         print("[ResultView] Share tapped. Recomputed unitsDisplay=\(unitsDisplay)")
    //
    //                         // Build and sanitize message, ensure non-empty fallback
    //                         let raw = buildShareMessage().trimmingCharacters(in: .whitespacesAndNewlines)
    //                         let message: String
    //                         if raw.isEmpty {
    //                             let carbsDisplay = totalCarbGrams.isEmpty ? "—" : totalCarbGrams
    //                             let confLabel = (Int(confidence) ?? 0) > 5 ? "Standard" : (Int(confidence) == nil ? "—" : "Low")
    //                             let unitsPart = unitsDisplay.isEmpty ? "" : "\nInsulin estimate: \(unitsDisplay) units"
    //                             message = "Total net carbs: \(carbsDisplay) g\nConfidence: \(confLabel)\n\n\(unitsPart)".trimmingCharacters(in: .whitespacesAndNewlines)
    //                             print("[ResultView] Share message built from fallback. Length=\(message.count)")
    //                         } else {
    //                             message = raw
    //                             print("[ResultView] Share message built from summary. Length=\(message.count)")
    //                         }
    //
    //                         // Present item-driven sheet to avoid race where the sheet reads stale (empty) text
    //                         shareItem = ShareText(text: message)
    //                         print("[ResultView] shareItem set. isNil=\(shareItem == nil)")
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
    //                         unitsDisplay = computeUnitsDisplay(totalCarbsString: totalCarbGrams, carbRatioValue: carbRatio)
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
    
    // Use explicit Section initializer to avoid trailing-closure parsing issues
    private var summaryAndConfidenceSection: some View {
        Section(
            content: {
                VStack(spacing: 14) { // Rule: Layout Spacing - Changed from 0 to 14 to provide spacing between meal summary and card
                    if !mealSummary.isEmpty {
                        Text(mealSummary)
                            .font(.title3) // Rule: Visual Design - Reduced from .title2 to .title3 for less prominence
                            .fontWeight(.regular) // Rule: Visual Design - Changed from .semibold to .regular for softer appearance
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 0) // Rule: Layout Spacing - Keep text at top of view
                            .padding(.bottom, 0) // Rule: Layout Spacing - Spacing controlled by parent VStack
                    }

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
                                Text(confidenceText)
                                    .font(.body)
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
                    .background(Color(UIColor.secondarySystemGroupedBackground)) // Rule: Visual Design - White background in light mode, dark in dark mode
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2) // Rule: Visual Design - Added shadow to match RecipeResultView
                    .padding(.bottom, 16) // Rule: Layout Spacing - Bottom padding for section spacing
                }
                .listRowInsets(EdgeInsets())
            },
        )
        .listRowBackground(EmptyView())
        .listRowSeparator(.hidden)
    }



    // Use explicit Section initializer to avoid trailing-closure parsing issues
    private var breakdownOfComponentsSection: some View {
        Section(
            content: {
                // Card container: Title + components inside the same padded box for consistent alignment and spacing
                VStack(alignment: .leading, spacing: 12) {
                    // Title inside the box
                    HStack {
                        Text("Breakdown of components")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        Spacer()
                    }

                    // Components list (title and items share the same leading inset)
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
                // Internal padding ensures space between box edge and content (title and items align)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(UIColor.secondarySystemBackground).opacity(0)) // Rule: Visual Design - Transparent background to match light mode appearance in dark mode
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color(UIColor.separator).opacity(0.7), lineWidth: 1.5) // Rule: Visual Design - Match border style from RecipeResultView for consistency
                )
            },
            footer: {
                VStack(alignment: .leading, spacing: 8) {
                    // Citation link - clickable text with info icon
                    Button {
                        print("[ResultView] Citation link tapped - opening web view")
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
        .listRowInsets(EdgeInsets()) // Move insets to the Section to avoid trailing-closure parsing issues
        .listRowBackground(EmptyView())
        .listRowSeparator(.hidden)
        .padding(.bottom, 4)
    }
    
    private var hasRenderableData: Bool {
        // We can render if we have parsed fields or a non-empty resultText JSON
        return !components.isEmpty || !totalCarbGrams.isEmpty || !mealSummary.isEmpty || (resultText?.isEmpty == false)
    }
    
    // MARK: - Quick Access Bar (Apple-style Menu Bar)
    
    private var quickAccessBar: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // MARK: - INSULIN DOSING - COMMENTED OUT - START
            // Only show quick-access bar if Loop integration is enabled OR if we're showing home button
            // When Loop is off and insulin dosing is commented out, there's nothing to show except Home
            // For history sheets (showHomeInQuickAccessBar == false), if Loop is off, bar should be hidden
            // MARK: - INSULIN DOSING - COMMENTED OUT - END
            
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
                // Rule: Apple Design Guidelines - Material background with prominent top border, extends into safe area with same material
                Rectangle()
                    .fill(.regularMaterial)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(Color(UIColor.separator).opacity(1)) // Rule: Visual Design - Increased opacity from 0.7 to 0.8 for more prominent separator
                            .frame(height: 0.5)
                    }
                    .ignoresSafeArea(edges: .bottom) // Rule: Visual Design - Extend material into safe area for cohesive appearance
            }
            .accessibilityIdentifier("quick-access-bar")
        }
    }

    var body: some View {
        Group { // Rules Applied: General Coding
            if isLoading && !hasRenderableData {
                VStack(spacing: 12) {
                    ProgressView("Analyzing...")
                    if let resultText, resultText.isEmpty == false {
                        Text(resultText)
                            .font(.footnote.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    Form { // Rules Applied: General Coding, SwiftUI-specific Patterns
                        summaryAndConfidenceSection
                        breakdownOfComponentsSection
                        
                        // Add bottom spacing to account for the quick-access-bar
                        Section {
                            Spacer()
                                .frame(height: 30)
                        }
                        .listRowBackground(EmptyView())
                        .listRowSeparator(.hidden)
                    }
                    .listSectionSpacing(0)
                    // Rule: Visual Design - Keep default Form background to match RecipeResultView (removed .scrollContentBackground(.hidden))
                }
            }
        }
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.large) // Rule: Apple Design Guidelines - Large title that collapses into nav bar when scrolling
        .navigationBarBackButtonHidden(true) // Rule: Visual Design - Removed Done button for cleaner UI, navigation handled by quick access bar
        .preferredColorScheme(nil)
        .overlay(alignment: .topLeading) {
            Text("Results")
                .font(.largeTitle)
                .hidden()
                .accessibilityIdentifier("result-header")
        }
        .onChange(of: resultText) { _, newValue in
            if let parsed = decodeAIResultV2(from: newValue) {
                components = parsed.components
                totalCarbGrams = String(parsed.totalCarbGrams)
                confidence = String(parsed.confidence)
                mealSummary = parsed.mealSummary
                // MARK: - INSULIN DOSING - COMMENTED OUT - START
                // unitsDisplay = computeUnitsDisplay(totalCarbsString: totalCarbGrams, carbRatioValue: carbRatio) // Updated call
                // MARK: - INSULIN DOSING - COMMENTED OUT - END
            }
        }
        // MARK: - INSULIN DOSING - COMMENTED OUT - START
        // .onChange(of: carbRatio) { _, newValue in // newValue is now Double
        //     unitsDisplay = computeUnitsDisplay(totalCarbsString: totalCarbGrams, carbRatioValue: newValue) // Updated call
        // }
        // MARK: - INSULIN DOSING - COMMENTED OUT - END
        .onAppear {
            if let parsed = decodeAIResultV2(from: resultText) {
                components = parsed.components
                totalCarbGrams = String(parsed.totalCarbGrams)
                confidence = String(parsed.confidence)
                mealSummary = parsed.mealSummary
                // MARK: - INSULIN DOSING - COMMENTED OUT - START
                // unitsDisplay = computeUnitsDisplay(totalCarbsString: totalCarbGrams, carbRatioValue: carbRatio) // Updated call
                // MARK: - INSULIN DOSING - COMMENTED OUT - END
            }
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
        .sheet(isPresented: $showingCitationWebView) {
            // Rule: General Coding - Safari view for citation link (same pattern as RecipeResultView)
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
        //             unitsDisplay = computeUnitsDisplay(totalCarbsString: totalCarbGrams, carbRatioValue: carbRatio)
        //             print("[ResultView] Insulin sheet appeared. unitsDisplay=\(unitsDisplay), carbRatio=\(carbRatio)")
        //         }
        // }
        // MARK: - INSULIN DOSING - COMMENTED OUT - END
    }
}

#Preview {
    @Previewable @State var text: String? = """
{
  "components": [
    {"description": "Brown rice", "estimatedWeightGrams": 180, "carbPercentage": 23, "carbContentGrams": 41},
    {"description": "Grilled chicken", "estimatedWeightGrams": 150, "carbPercentage": 0, "carbContentGrams": 0},
    {"description": "Broccoli", "estimatedWeightGrams": 120, "carbPercentage": 7, "carbContentGrams": 8}
  ],
  "totalCarbGrams": 49,
  "confidence": 8,
  "mealSummary": "Grilled chicken with brown rice and broccoli"
}
"""
    @Previewable @State var loading = false
    return NavigationStack {
        ResultView(
            resultText: $text,
            isLoading: $loading,
            onDone: { print("Simulating pop to root in preview") } // Example for preview
        )
    }
}

