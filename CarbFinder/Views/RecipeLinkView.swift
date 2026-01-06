//
//  RecipeLinkView.swift
//  CarbFinder
//
//  Created by Diego Szekely on 06.11.25.
//

import SwiftUI

// MARK: - Favicon Helper Functions
// Rule: General Coding - Separate helper functions for clarity and reusability

/// Fetches the favicon for a given URL
/// - Parameter url: The website URL to fetch the favicon from
/// - Returns: UIImage of the favicon, or nil if fetch fails
private func fetchFavicon(for url: URL) async -> UIImage? {
    // Rule: General Coding - Add debug logs for easier debugging
    guard let host = url.host() else {
        print("[Favicon] No host found in URL: \(url)")
        return nil
    }
    
    // Try multiple favicon sources in order of preference
    // Rule: General Coding - Comprehensive fallback strategy for robust fetching
    let faviconURLs = [
        URL(string: "https://\(host)/apple-touch-icon.png"), // High-res Apple touch icon
        URL(string: "https://\(host)/favicon.ico"),          // Standard favicon
        URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=128") // Google favicon service as fallback
    ].compactMap { $0 }
    
    for faviconURL in faviconURLs {
        print("[Favicon] Trying to fetch from: \(faviconURL)")
        do {
            let (data, response) = try await URLSession.shared.data(from: faviconURL)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  let image = UIImage(data: data) else {
                print("[Favicon] Failed to fetch or decode from: \(faviconURL)")
                continue
            }
            print("[Favicon] ✅ Successfully fetched favicon from: \(faviconURL)")
            return image
        } catch {
            print("[Favicon] Error fetching from \(faviconURL): \(error)")
        }
    }
    
    print("[Favicon] ❌ All favicon sources failed for: \(host)")
    return nil
}

/// Creates a composite image with the background image and favicon overlay
/// - Parameters:
///   - backgroundImageName: Name of the background image in Assets
///   - faviconImage: The favicon image to overlay (optional)
/// - Returns: Composite UIImage, or nil if background image not found
private func createLinkHistoryImage(backgroundImageName: String, faviconImage: UIImage?) -> UIImage? {
    // Rule: General Coding - Add debug logs for easier debugging
    guard let backgroundImage = UIImage(named: backgroundImageName) else {
        print("[LinkImage] ❌ Background image '\(backgroundImageName)' not found in assets")
        return nil
    }
    
    let size = backgroundImage.size
    print("[LinkImage] Creating composite image with size: \(size)")
    
    // Rule: Performance Optimization - Use image renderer for efficient compositing
    let renderer = UIGraphicsImageRenderer(size: size)
    let compositeImage = renderer.image { context in
        // Draw background
        backgroundImage.draw(in: CGRect(origin: .zero, size: size))
        
        // Draw favicon - FINAL APPROVED SPECIFICATIONS (do not revert)
        // Size: 28% | Position: 10% lower in visible area | Shadow: offset=3, blur=7, opacity=0.18
        if let favicon = faviconImage {
            let faviconWidth = size.width * 0.28
            let faviconSize = CGSize(width: faviconWidth, height: faviconWidth)
            let faviconX = (size.width - faviconWidth) / 2
            
            // FINAL POSITIONING - accounts for 30% bottom overlay with 10% downward offset
            let overlayHeight = size.height * 0.30
            let visibleHeight = size.height - overlayHeight
            let faviconY = (visibleHeight / 2) - (faviconWidth / 2) + (visibleHeight * 0.10)
            
            let faviconRect = CGRect(x: faviconX, y: faviconY, width: faviconWidth, height: faviconWidth)
            let whiteBoxCornerRadius = faviconWidth * 0.225
            
            // FINAL SHADOW - intermediate style
            context.cgContext.saveGState()
            context.cgContext.setShadow(
                offset: CGSize(width: 0, height: 3),
                blur: 7,
                color: UIColor.black.withAlphaComponent(0.18).cgColor
            )
            
            let backgroundPath = UIBezierPath(roundedRect: faviconRect, cornerRadius: whiteBoxCornerRadius)
            UIColor.white.setFill()
            backgroundPath.fill()
            context.cgContext.restoreGState()
            
            // Draw favicon with rounded corners
            let inset: CGFloat = faviconWidth * 0.1
            let insetRect = faviconRect.insetBy(dx: inset, dy: inset)
            let faviconCornerRadius = insetRect.width * 0.225
            
            context.cgContext.saveGState()
            let faviconPath = UIBezierPath(roundedRect: insetRect, cornerRadius: faviconCornerRadius)
            faviconPath.addClip()
            favicon.draw(in: insetRect)
            context.cgContext.restoreGState()
            
            print("[LinkImage] ✅ Drew favicon: size=\(faviconSize), y=\(faviconY), shadow=(3,7,0.18)")
        } else {
            print("[LinkImage] No favicon provided, using background only")
        }
    }
    
    print("[LinkImage] ✅ Composite image created successfully")
    return compositeImage
}

struct RecipeLinkView: View {
    let onDismiss: () -> Void
    let historyStore: ScanHistoryStore // Rule: State Management - Pass dependency to constructor
    let usageManager: CaptureUsageManager // Rule: State Management - Pass usage manager for tracking
    
    @State private var urlString: String = ""
    @State private var isAnalyzing: Bool = false
    @State private var showInvalidURLAlert: Bool = false
    
    // Navigation state for results
    @State private var navigateToLoading: Bool = false
    @State private var navigateToResult: Bool = false
    @State private var navigateToError: Bool = false // Rule: General Coding - Navigate to error view when no content detected
    @State private var navigateToOverloadError: Bool = false // Rule: General Coding - Navigate to overload error view for 503
    @State private var errorType: ContentDetectionError = .invalidRecipeURL // Store specific error type
    @State private var aiCompleted: Bool = false // Rule: State Management - Separate state for success animation
    @State private var resultText: String? = nil
    @State private var recipeURL: URL? = nil // Store the URL for the result view
    @State private var aiRequestTask: Task<Void, Never>? = nil // Rule: State Management - Hold reference to AI task for tracking
    @State private var hasReceivedResponse = false // Rule: State Management - Track if we've received ANY response (success or error)
    @State private var wasBackgrounded = false // Rule: State Management - Track if we've been backgrounded during this loading session
    @State private var backgroundedAt: Date? = nil // Rule: State Management - Track when app was backgrounded
    @AppStorage("linkBackgroundIndex") private var linkBackgroundIndex: Int = 0 // Persistent index for cycling link backgrounds
    
    // Rule: SwiftUI Lifecycle - Monitor app lifecycle to handle backgrounding gracefully
    @Environment(\.scenePhase) private var scenePhase

    // Computed property to validate and normalize the URL
    // Rule: General Coding - Comprehensive URL validation
    private var parsedURL: URL? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        // Try to parse the URL as-is first
        if let url = URL(string: trimmed), isValidRecipeURL(url) {
            return url
        }
        
        // If no scheme provided, try adding https://
        if let url = URL(string: "https://" + trimmed), isValidRecipeURL(url) {
            return url
        }
        
        return nil
    }
    
    // Helper to validate that URL has proper structure for a recipe
    // Rule: General Coding - Separate validation logic for clarity
    private func isValidRecipeURL(_ url: URL) -> Bool {
        // Must have http or https scheme
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            print("[URL Validation] Invalid scheme: \(url.scheme ?? "nil")") // Rule: General Coding - Add debug logs
            return false
        }
        
        // Must have a valid host
        guard let host = url.host(), !host.isEmpty else {
            print("[URL Validation] Missing or empty host") // Rule: General Coding - Add debug logs
            return false
        }
        
        // Host should contain at least one dot (e.g., example.com)
        guard host.contains(".") else {
            print("[URL Validation] Invalid host format: \(host)") // Rule: General Coding - Add debug logs
            return false
        }
        
        print("[URL Validation] Valid URL: \(url.absoluteString)") // Rule: General Coding - Add debug logs
        return true
    }
    
    // Fetches the page content and extracts readable text
    // Rule: Networking - Keep networking minimal and robust; strip HTML/script/style; limit size
    private func fetchReadableText(from url: URL) async throws -> String {
        var request = URLRequest(url: url)
        // Some sites block default URLSession UA; send a common browser-like UA
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<no body>"
            print("[RecipeLinkView] HTTP \(http.statusCode) while fetching page: \(body.prefix(300))…")
            throw NSError(domain: "RecipeFetch", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP status \(http.statusCode)"])
        }

        // Try UTF-8 decode; fall back to ISO Latin1 if needed
        let html = String(data: data, encoding: .utf8) ?? (String(data: data, encoding: .isoLatin1) ?? "")
        return extractVisibleText(fromHTML: html)
    }

    // Very lightweight HTML -> text extractor
    private func extractVisibleText(fromHTML html: String) -> String {
        var text = html
        // Remove scripts and styles
        text = text.replacingOccurrences(of: "(?is)<script[\\s\\S]*?</script>", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?is)<style[\\s\\S]*?</style>", with: " ", options: .regularExpression)
        // Remove head
        text = text.replacingOccurrences(of: "(?is)<head[\\s\\S]*?</head>", with: " ", options: .regularExpression)
        // Replace tags with spaces
        text = text.replacingOccurrences(of: "(?s)<[^>]+>", with: " ", options: .regularExpression)
        // Decode common HTML entities (basic subset)
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
                   .replacingOccurrences(of: "&amp;", with: "&")
                   .replacingOccurrences(of: "&quot;", with: "\"")
                   .replacingOccurrences(of: "&#39;", with: "'")
                   .replacingOccurrences(of: "&lt;", with: "<")
                   .replacingOccurrences(of: "&gt;", with: ">")
        // Collapse whitespace
        let components = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        var collapsed = components.joined(separator: " ")
        // Heuristic: trim to a reasonable size to keep token usage low
        let maxChars = 12000
        if collapsed.count > maxChars {
            collapsed = String(collapsed.prefix(maxChars))
        }
        print("[RecipeLinkView] Extracted text length: \(collapsed.count) chars")
        return collapsed
    }

    private func analyzeTapped() {
        guard let url = parsedURL else {
            print("[RecipeLinkView] Analysis failed - invalid URL") // Rule: General Coding - Add debug logs
            showInvalidURLAlert = true
            return
        }
        
        print("[RecipeLinkView] Starting analysis for: \(url.absoluteString)") // Rule: General Coding - Add debug logs
        
        // Rule: General Coding - Navigate to loading screen first for better UX
        isAnalyzing = true
        recipeURL = url
        navigateToLoading = true
        
        // Rule: Push Notifications - Mark analysis as started
        AnalysisNotificationManager.shared.isAnalyzing = true
        
        // Rule: State Management - Create and store AI request task for tracking
        aiRequestTask = Task { @MainActor in
            let client = GeminiClient()
            let prompt = """
            Analyze the recipe from the provided URL context and extract detailed ingredient information.
            
            FIRST: Check if the webpage contains a recipe. If the content is NOT a recipe (e.g., blog post, article, product page, error page, or webpage is inaccessible), return:
            {
              "noContent": true,
              "contentError": string,              // one of: "not_a_recipe", "inaccessible"
              "components": [],
              "totalCarbGrams": 0,
              "confidence": 0,
              "recipeDescription": "No recipe found"
            }
            
            If a recipe IS found, for EACH ingredient in the recipe:
            - Identify the ingredient name
            - Estimate the weight in grams (for raw ingredients as listed in the recipe)
            - Determine the carbohydrate percentage for that ingredient
            - Calculate the net carb content in grams
            
            Then calculate the total net carbohydrates for the ENTIRE RECIPE (sum of all ingredient carb contents).

            Please analyze the recipe content that has been fetched from the URL. Consider all visible ingredients and their quantities. If quantities are missing or unclear, estimate based on typical recipe proportions and indicate lower confidence.

            Return ONLY valid JSON (no markdown fences, no extra commentary). Use this exact schema:
            {
              "noContent": boolean,                // true if no recipe or inaccessible, false otherwise
              "contentError": string,              // "not_a_recipe" or "inaccessible" (only if noContent is true)
              "components": [
                {
                  "description": string,           // ingredient name
                  "estimatedWeightGrams": number,  // grams of this ingredient
                  "carbPercentage": number,        // percentage as whole number (e.g., 23)
                  "carbContentGrams": number       // net carbs in grams for this ingredient
                }
              ],
              "totalCarbGrams": number,            // sum of all components' carbContentGrams
              "confidence": integer,               // 1-9 (0 if noContent is true)
              "recipeDescription": string          // one-line description 3-5 words
            }

            Rules:
            - Use grams for weights and net carbohydrate content. Prefer integers where reasonable.
            - Express carbPercentage as a whole number (e.g., 23 for 23%).
            - Ensure totalCarbGrams equals the sum of all component carbContentGrams.
            - Ensure the JSON is syntactically valid and parseable by JSONDecoder.
            - Do not include any text before or after the JSON.
            - If ingredients or quantities are unclear or missing, reduce confidence accordingly
            - Set noContent to true and contentError to "not_a_recipe" if the content doesn't contain a recipe
            - Set noContent to true and contentError to "inaccessible" if the page content suggests the page couldn't be accessed
            - Always use NET carbs
            """

            do {
                print("[RecipeLinkView] Fetching page content for inline analysis…")
                let pageText = try await fetchReadableText(from: url)

                // Build a combined prompt that includes the fetched page text
                let combinedPrompt = prompt + "\n\nUse the following page content as the ONLY source of truth for the recipe. If it doesn't contain a recipe, respond with confidence: 0.\nPAGE CONTENT:\n\"\"\"\n" + pageText + "\n\"\"\"\n"

                print("[RecipeLinkView] Calling Gemini API with inline page content (no URL grounding)")
                let text = try await client.send(images: [], prompt: combinedPrompt)
                print("[RecipeLinkView] ✅ Response received successfully")
                print("[RecipeLinkView] Response length: \(text.count) characters")
                print("[RecipeLinkView] Raw response: \(text)")
                
                // Rule: State Management - Mark that we received a response
                hasReceivedResponse = true
                resultText = text
                
                // Rule: General Coding - Check if AI detected no content BEFORE incrementing usage
                // Parse the response to check for noContent flag
                let sanitized = sanitizeJSONText(text)
                if let data = sanitized.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let noContent = json["noContent"] as? Bool,
                   noContent == true {
                    let contentError = json["contentError"] as? String ?? "not_a_recipe"
                    print("[RecipeLinkView] ⚠️ AI detected no recipe content, error type: \(contentError)")
                    // DO NOT increment usage count for no-content detections
                    // DO NOT save to history for no-content detections
                    
                    // Rule: Push Notifications - Send notification with appropriate error message
                    let errorMessage: String
                    if contentError == "inaccessible" {
                        errorMessage = "The page can't be accessed"
                    } else {
                        errorMessage = "The link isn't a recipe"
                    }
                    
                    await MainActor.run {
                        AnalysisNotificationManager.shared.notifyNoContent(errorMessage: errorMessage)
                    }
                    
                    // Determine error type and navigate to error view
                    errorType = contentError == "inaccessible" ? .inaccessibleURL : .invalidRecipeURL
                    aiCompleted = true
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    navigateToError = true
                    return // Exit early
                }
                
                // Rule: General Coding - Increment capture count after successful AI response with content
                await MainActor.run {
                    usageManager.incrementCaptureCount()
                    print("[RecipeLink] Capture count incremented after successful AI response")
                }
                
                // Rule: State Management - Update state with delay for success animation
                // First show success state in LoadingView (green circle)
                print("[RecipeLinkView] AI response complete. Setting success state...")
                aiCompleted = true
                
                // Rule: Push Notifications - Mark analysis as complete
                AnalysisNotificationManager.shared.isAnalyzing = false
                
                // Wait for success animation to complete (0.3s delay as requested)
                // Rule: General Coding - Visual feedback before navigation
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                print("[RecipeLinkView] Success animation complete, navigating to result screen")
                navigateToResult = true
                print("[RecipeLinkView] Analysis completed for: \(url.absoluteString)")
                
                // Rule: General Coding - Save to history with composite image for link-based recipes
                // Build estimate string for history (reuse existing decoding logic from RecipeResultView)
                var estimateString = ""
                var totalCarbsForNotification: Int = 0
                var recipeDescForNotification: String = ""
                
                if let text = resultText,
                   let parsed = decodeRecipeAIResult(from: text) {
                    totalCarbsForNotification = parsed.totalCarbGrams
                    recipeDescForNotification = parsed.recipeDescription
                    if parsed.recipeDescription.isEmpty {
                        estimateString = "~\(parsed.totalCarbGrams)g carbs"
                    } else {
                        estimateString = "~\(parsed.totalCarbGrams)g carbs · \(parsed.recipeDescription)"
                    }
                }
                
                if estimateString.isEmpty {
                    estimateString = "Recipe · Unavailable"
                }
                print("[RecipeLinkView] History estimate string: \(estimateString)")
                
                // FINAL BACKGROUND CYCLING - cycles through background1 to background5 using persistent index
                // Rule: State Management - Uses @AppStorage counter that persists independently of history size
                // This ensures background rotation continues correctly even with 500 max entries (up from 10)
                // The counter is NEVER reset and continues incrementing forever, cycling via modulo operator
                print("[RecipeLinkView] Fetching favicon for history image...")
                let favicon = await fetchFavicon(for: url)

                // Use persistent index to avoid dependence on history size or filtering
                let backgroundNumber = (linkBackgroundIndex % 5) + 1
                let backgroundName = "background\(backgroundNumber)"
                print("[RecipeLinkView] Using \(backgroundName) (linkBackgroundIndex: \(linkBackgroundIndex))")
                
                guard let compositeImage = createLinkHistoryImage(
                    backgroundImageName: backgroundName,
                    faviconImage: favicon
                ) else {
                    print("[RecipeLinkView] ❌ Failed to create composite image, skipping history save")
                    return
                }
                
                // Save to history with the composite image
                let jsonForHistory = sanitizeJSONText(resultText ?? "")
                await MainActor.run {
                    print("[RecipeLinkView] Saving to history with composite image")
                    historyStore.addEntry(
                        firstImage: compositeImage,
                        carbEstimate: estimateString,
                        aiResultJSON: jsonForHistory,
                        recipeURLString: recipeURL?.absoluteString
                    )
                    print("[RecipeLinkView] ✅ Successfully saved link-based recipe to history")
                    linkBackgroundIndex += 1
                    print("[RecipeLinkView] linkBackgroundIndex incremented to \(linkBackgroundIndex)")
                }
                
                // Rule: Push Notifications - Send notification if app is in background
                if totalCarbsForNotification > 0 {
                    await MainActor.run {
                        AnalysisNotificationManager.shared.notifyAnalysisComplete(
                            totalCarbs: totalCarbsForNotification,
                            mealSummary: recipeDescForNotification
                        )
                    }
                }
            } catch {
                print("[RecipeLinkView] ❌ ERROR occurred during fetch or AI call")
                print("[RecipeLinkView] Error type: \(type(of: error))")
                print("[RecipeLinkView] Error description: \(error)")
                
                // Rule: State Management - Mark that we received a response (even if error)
                hasReceivedResponse = true
                
                // Rule: Error Handling - Check if error is due to backgrounding/network interruption
                let nsError = error as NSError
                let isNetworkInterruption = (nsError.domain == NSURLErrorDomain && 
                                             (nsError.code == NSURLErrorCancelled || 
                                              nsError.code == NSURLErrorNetworkConnectionLost ||
                                              nsError.code == NSURLErrorNotConnectedToInternet))
                
                if isNetworkInterruption {
                    // Rule: Error Handling - Don't show error for network interruptions during backgrounding
                    print("[RecipeLinkView] ⚠️ Network interruption detected (likely due to backgrounding). Staying on loading screen.")
                    await MainActor.run {
                        // Don't set aiCompleted or navigate to error
                        // LoadingView will continue showing, user can dismiss via navigation if needed
                    }
                } else {
                    // Rule: Error Handling - Show AI overload error for actual API errors
                    print("[RecipeLink] ❌ Parsing/AI error - navigating to overload error view")
                    await MainActor.run {
                        isAnalyzing = false
                        navigateToLoading = false
                        // DO NOT increment usage count
                        // DO NOT save to history
                        
                        // Rule: Push Notifications - Mark analysis as complete (failed)
                        AnalysisNotificationManager.shared.isAnalyzing = false
                        
                        // Rule: Push Notifications - Send notification for AI overload error
                        AnalysisNotificationManager.shared.notifyAIOverload()
                        
                        // Navigate to overload error view after animation
                        aiCompleted = true
                    }
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    await MainActor.run {
                        navigateToOverloadError = true
                    }
                }
            }
        }
    }
    
    /// Sanitizes JSON text by removing markdown fences and extracting the JSON object
    /// Rule: No Duplication - Keep this helper local since it's specific to this flow
    private func sanitizeJSONText(_ text: String) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            t = t.replacingOccurrences(of: "```json", with: "")
            t = t.replacingOccurrences(of: "```", with: "")
        }
        if let firstBrace = t.firstIndex(of: "{"), let lastBrace = t.lastIndex(of: "}") {
            let range = firstBrace...lastBrace
            return String(t[range])
        }
        return t
    }
    
    var body: some View {
        // Rule: General Coding - Modern Apple-style design with grouped form style
        Form {
            Section {
                // URL Input Field with integrated validation indicator
                // Rule: General Coding - Refined spacing and sizing for cleaner appearance
                HStack(spacing: 10) {
                    TextField("", text: $urlString, prompt: Text("Enter recipe URL").foregroundStyle(.tertiary))
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textContentType(.URL)
                        .submitLabel(.go)
                        .onSubmit { analyzeTapped() }
                        .font(.body)
                    
                    // Rule: General Coding - Show checkmark for valid URL, paste button otherwise
                    if parsedURL != nil {
                        // Valid URL - show green checkmark with animation
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 19, weight: .medium))
                            .foregroundStyle(.green)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        // No valid URL - show paste button
                        Button(action: {
                            print("[RecipeLinkView] Paste button tapped") // Rule: General Coding - Add debug logs
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            
                            // Get text from clipboard
                            if let clipboardString = UIPasteboard.general.string {
                                urlString = clipboardString
                                print("[RecipeLinkView] Pasted from clipboard: \(clipboardString)") // Rule: General Coding - Add debug logs
                            }
                        }) {
                            Image(systemName: "doc.on.clipboard")
                                .font(.system(size: 19, weight: .medium))
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8) // Rule: General Coding - Refined vertical padding for better proportion
            } header: {
                // Rule: Apple Design Guidelines - Clear section header
                Label("Recipe URL", systemImage: "link")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .textCase(nil)
            } footer: {
                // Rule: Apple Design Guidelines - Helpful footer text
                Text("Paste the link to any online recipe and we'll analyze it for ingredients and nutrition.")
                    .font(.footnote)
            }
            
            Section {
                // Analyze Button with full-width design
                Button {
                    analyzeTapped()
                } label: {
                    HStack {
                        if isAnalyzing {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        } else {
                            Text("Analyze Recipe")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44) // Rule: Apple Design Guidelines - 44pt minimum touch target
                }
                .buttonStyle(.borderedProminent)
                .disabled(parsedURL == nil || isAnalyzing)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                .listRowBackground(Color.clear)
            }
        }
        .formStyle(.grouped) // Rule: Apple Design Guidelines - Use grouped form style for modern look
        .animation(.easeInOut(duration: 0.2), value: parsedURL != nil) // Rule: General Coding - Smooth transition animation
        .navigationTitle("Online recipes")
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: {
                    print("[RecipeLinkView] Close tapped")
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onDismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .accessibilityLabel("Close")
                .accessibilityIdentifier("cancel-button")
            }
        }
        .alert("Invalid URL", isPresented: $showInvalidURLAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please enter a valid recipe URL. Make sure it starts with http:// or https:// and includes a domain name (e.g., allrecipes.com).")
        }
        .navigationDestination(isPresented: $navigateToLoading) {
            // Rule: SwiftUI-specific Patterns - Navigate to loading screen first
            LoadingView(aiCompleted: $aiCompleted, scanType: .recipe)
                .navigationDestination(isPresented: $navigateToResult) {
                    // Once AI completes, navigate from loading to result
                    // Rule: State Management - Nested navigation for loading -> result flow
                    RecipeResultView(
                        resultText: $resultText,
                        isLoading: $isAnalyzing,
                        recipeImage: nil, // No image for URL-based recipes
                        recipeURL: recipeURL, // Pass the URL instead
                        onDone: {
                            print("[RecipeLinkView] ResultView Done button tapped -> dismissing flow")
                            onDismiss()
                        }
                    )
                }
                .navigationDestination(isPresented: $navigateToError) {
                    // Rule: General Coding - Show error view when no content detected
                    NoContentErrorView(errorType: errorType, onDismiss: {
                        print("[RecipeLinkView] NoContentErrorView dismissed -> dismissing flow")
                        onDismiss()
                    })
                }
                .navigationDestination(isPresented: $navigateToOverloadError) {
                    // Rule: General Coding - Show overload error view for 503 errors
                    AIOverloadErrorView(onDismiss: {
                        print("[RecipeLinkView] AIOverloadErrorView dismissed -> dismissing flow")
                        onDismiss()
                    })
                }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Rule: SwiftUI Lifecycle - Monitor scene phase to handle app backgrounding gracefully
            print("[RecipeLinkView] Scene phase changed: \(oldPhase) -> \(newPhase)")
            
            if newPhase == .background {
                print("[RecipeLinkView] 🌙 App entered background")
                
                // Rule: State Management - Track when we backgrounded
                if navigateToLoading && !hasReceivedResponse {
                    backgroundedAt = Date()
                    wasBackgrounded = true
                    print("[RecipeLinkView] ⚠️ Loading screen backgrounded - request may be suspended by iOS")
                }
            }
            
            if newPhase == .active {
                print("[RecipeLinkView] ☀️ App is now active")
                print("[RecipeLinkView] State - navigateToLoading: \(navigateToLoading), navigateToResult: \(navigateToResult), aiCompleted: \(aiCompleted), hasReceivedResponse: \(hasReceivedResponse), wasBackgrounded: \(wasBackgrounded)")
                
                if oldPhase == .background {
                    print("[RecipeLinkView] 🔄 App returned from background")
                    
                    // CRITICAL: If we were loading and backgrounded, we need to check the state immediately
                    if navigateToLoading && wasBackgrounded && !hasReceivedResponse {
                        let timeSinceBackground = backgroundedAt.map { Date().timeIntervalSince($0) } ?? 0
                        
                        print("[RecipeLinkView] ⏱️ Time since background: \(String(format: "%.1f", timeSinceBackground))s")
                        
                        // Rule: Error Handling - iOS suspends network tasks after backgrounding
                        // Without a debugger attached, URLSession requests are often suspended
                        // and won't complete. We need to detect this and fail gracefully.
                        //
                        // AGGRESSIVE TIMEOUT: If backgrounded for >2 seconds without response,
                        // assume the request is stuck and won't complete.
                        if timeSinceBackground > 2.0 {
                            print("[RecipeLinkView] ❌ Request suspended by iOS backgrounding (>2s) - cancelling and going back")
                            
                            // Cancel the suspended task
                            aiRequestTask?.cancel()
                            aiRequestTask = nil
                            
                            // Mark as received response to prevent infinite waiting
                            hasReceivedResponse = true
                            wasBackgrounded = false
                            
                            // Rule: Push Notifications - Mark analysis as complete (failed)
                            AnalysisNotificationManager.shared.isAnalyzing = false
                            
                            // Rule: Error Handling - Go back to home instead of showing error
                            // This is cleaner UX - user can just try again
                            print("[RecipeLinkView] Going back to home screen")
                            DispatchQueue.main.async {
                                // Call onDismiss to dismiss the entire flow
                                onDismiss()
                            }
                            return
                        } else {
                            print("[RecipeLinkView] ℹ️ Brief background (<2s), waiting for response...")
                        }
                    }
                    
                    // Rule: State Management - Check if we already have a result
                    // If aiCompleted is true, the AI finished while backgrounded - show results
                    if aiCompleted && resultText != nil && navigateToLoading && !navigateToResult && !navigateToError && !navigateToOverloadError {
                        print("[RecipeLinkView] ✅ AI completed while backgrounded, triggering navigation to result")
                        // Trigger navigation by setting the flag
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            navigateToResult = true
                        }
                        return
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        RecipeLinkView(
            onDismiss: {
                print("Dismissed in preview")
            },
            historyStore: ScanHistoryStore(),
            usageManager: CaptureUsageManager()
        )
    }
}

