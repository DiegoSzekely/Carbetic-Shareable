//  RecipeScanFlow.swift
//  CarbFinder
//
//  Recipe scanning flow: single-photo capture → AI analysis → results display
//  Rules Applied: State Management, No Duplication (reuse camera & AI), Apple Design Guidelines

import SwiftUI
import UIKit
import AVFoundation

// MARK: - Storage for Recipe Capture

/// Simple storage for a single recipe image (no observation required)
final class RecipeCaptureStorage {
    var recipeImage: UIImage? {
        didSet { print("[RecipeStorage] recipeImage set: \(recipeImage != nil)") }
    }
    
    func clear() {
        recipeImage = nil
        print("[RecipeStorage] Image cleared")
    }
}

// MARK: - Recipe Capture View

struct RecipeCaptureView: View {
    let storage: RecipeCaptureStorage
    let onCancel: () -> Void
    let historyStore: ScanHistoryStore
    let usageManager: CaptureUsageManager // Rule: State Management - Pass usage manager for tracking
    
    @StateObject private var camera = CaptureSessionCoordinator()
    @State private var auth: CameraAuthorizationStatus = .notDetermined
    @State private var goToLoading = false
    @State private var goToResult = false
    @State private var goToError = false // Rule: General Coding - Navigate to error view when no content detected
    @State private var goToOverloadError = false // Rule: General Coding - Navigate to overload error view for 503
    @State private var aiCompleted = false // Rule: State Management - Separate state for success animation
    @State private var resultText: String? = nil
    @State private var isLoading = false
    @State private var aiRequestTask: Task<Void, Never>? = nil // Rule: State Management - Hold reference to AI task for tracking
    @State private var hasReceivedResponse = false // Rule: State Management - Track if we've received ANY response (success or error)
    @State private var wasBackgrounded = false // Rule: State Management - Track if we've been backgrounded during this loading session
    @State private var backgroundedAt: Date? = nil // Rule: State Management - Track when app was backgrounded
    @State private var isCapturing = false // Rule: State Management - Track capture in progress for loading indicator
    @Environment(\.colorScheme) private var colorScheme
    
    // Rule: SwiftUI Lifecycle - Monitor app lifecycle to handle backgrounding gracefully
    @Environment(\.scenePhase) private var scenePhase
    
    /// Helper to handle cancel action - stops camera before dismissing
    /// Rule: General Coding - Ensure cleanup happens before navigation for smooth UX
    private func handleCancel() {
        print("[RecipeCapture] Cancel requested - stopping camera first")
        camera.stop() // Stop camera immediately (runs on background thread internally)
        onCancel() // Then dismiss
    }
    
    var body: some View {
        ZStack {
            if auth == .authorized {
                // Use GeometryReader to match the meal capture layout exactly
                GeometryReader { geo in
                    let totalHeight = geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom
                    
                    VStack(spacing: 0) {
                        ZStack(alignment: .top) {
                            // Camera preview - full height
                            CameraPreview(coordinator: camera)
                                .frame(height: totalHeight)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .background(Color.black)
                                .accessibilityIdentifier("camera-preview")
                            
                            // Top darkening gradient
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.black.opacity(0.66),
                                    Color.black.opacity(0.42),
                                    Color.black.opacity(0.19),
                                    Color.black.opacity(0.0)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: geo.safeAreaInsets.top + totalHeight * 0.14)
                            .frame(maxWidth: .infinity, alignment: .top)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                            
                            // Description pill (centered)
                            HStack(alignment: .firstTextBaseline, spacing: 5) {
                                Text("Capture ingredients page")
                                    .font(.headline)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(.top, geo.safeAreaInsets.top + totalHeight * 0.02)
                            .frame(maxWidth: .infinity)
                            .accessibilityIdentifier("description-pill")
                            .accessibilityLabel("Capture instructions")
                            
                            // Leading close button
                            Button(action: {
                                print("[RecipeCapture] Close tapped")
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                handleCancel() // Use helper that stops camera first
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(10)
                            }
                            .background(.ultraThinMaterial, in: Circle())
                            .padding(.top, geo.safeAreaInsets.top + totalHeight * 0.02)
                            .padding(.leading, 20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel("Close")
                            .accessibilityIdentifier("cancel-button")
                        }
                        
                        // Bottom control area (white with rounded top corners)
                        ZStack {
                            // Capture button centered
                            VStack(spacing: 0) {
                                captureButton {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    print("[RecipeCapture] Capture button tapped")
                                    
                                    // Rule: General Coding - Show loading indicator during capture
                                    isCapturing = true
                                    
                                    camera.capture { image in
                                        // Rule: General Coding - Always hide loading indicator in completion
                                        isCapturing = false
                                        
                                        guard let img = image else {
                                            print("[RecipeCapture] ❌ Failed to capture image - session may have been stopped")
                                            // Don't navigate if capture failed
                                            return
                                        }
                                        
                                        storage.recipeImage = img
                                        print("[RecipeCapture] Image captured, navigating to loading screen")
                                        
                                        // Explicitly stop the camera before navigating to ensure the session ends.
                                        camera.stop()
                                        
                                        // Rule: General Coding - Navigate to loading screen first for better UX
                                        goToLoading = true
                                        
                                        // Rule: Push Notifications - Mark analysis as started
                                        AnalysisNotificationManager.shared.isAnalyzing = true
                                        
                                        // Rule: State Management - Create and store AI request task for tracking
                                        aiRequestTask = Task { @MainActor in
                                            let client = GeminiClient()
                                            let prompt = """
                                            Analyze this recipe image and extract detailed ingredient information.
                                            
                                            FIRST: Check if the image contains a recipe. If NO recipe is visible (e.g., just random objects, landscape, people), return:
                                            {
                                              "noContent": true,
                                              "components": [],
                                              "totalCarbGrams": 0,
                                              "confidence": 0,
                                              "recipeDescription": "No recipe detected"
                                            }
                                            
                                            If a recipe IS visible, for EACH ingredient in the recipe:
                                            - Identify the ingredient name
                                            - Estimate the weight in grams (for raw ingredients as listed in the recipe)
                                            - Determine the carbohydrate percentage for that ingredient
                                            - Calculate the net carb content in grams
                                            
                                            Then calculate the total net carbohydrates for the ENTIRE RECIPE (sum of all ingredient carb contents).

                                            Consider all visible ingredients and their quantities. If quantities are missing or unclear, estimate based on typical recipe proportions and indicate lower confidence.

                                            Return ONLY valid JSON (no markdown fences, no extra commentary). Use this exact schema:
                                            {
                                              "noContent": boolean,                // true if no recipe detected, false otherwise
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
                                            - If text is unclear or partially visible, reduce confidence accordingly
                                            - Always use NET carbs
                                            - Set noContent to true ONLY if no recipe is visible in the image
                                            """
                                            
                                            if let recipeImg = storage.recipeImage {
                                                do {
                                                    let text = try await client.send(images: [recipeImg], prompt: prompt)
                                                    print("[RecipeAI] Response received, length: \(text.count)")
                                                    
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
                                                        print("[RecipeAI] ⚠️ AI detected no recipe in image, navigating to error view")
                                                        // DO NOT increment usage count for no-content detections
                                                        // DO NOT save to history for no-content detections
                                                        
                                                        // Rule: Push Notifications - Send notification for no-content error
                                                        await MainActor.run {
                                                            AnalysisNotificationManager.shared.notifyNoContent(
                                                                errorMessage: "There is no recipe visible"
                                                            )
                                                        }
                                                        
                                                        // Navigate directly to error view after animation
                                                        aiCompleted = true
                                                        try? await Task.sleep(nanoseconds: 300_000_000)
                                                        goToError = true
                                                        return // Exit early
                                                    }
                                                    
                                                    // Rule: General Coding - Increment capture count after successful AI response with content
                                                    await MainActor.run {
                                                        usageManager.incrementCaptureCount()
                                                        print("[RecipeCapture] Capture count incremented after successful AI response")
                                                    }
                                                    
                                                    // Rule: State Management - Update state with delay for success animation
                                                    // First show success state in LoadingView (green circle)
                                                    print("[RecipeCapture] AI response complete. Setting success state...")
                                                    aiCompleted = true
                                                    
                                                    // Rule: Push Notifications - Mark analysis as complete
                                                    AnalysisNotificationManager.shared.isAnalyzing = false
                                                    
                                                    // Wait for success animation to complete (0.3s delay as requested)
                                                    // Rule: General Coding - Visual feedback before navigation
                                                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                                                    print("[RecipeCapture] Success animation complete, navigating to result screen")
                                                    goToResult = true
                                                    
                                                    // Build estimate string for history
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
                                                    
                                                    // Save to history
                                                    if let img = storage.recipeImage {
                                                        let jsonForHistory = sanitizeJSONText(resultText ?? "")
                                                        await MainActor.run {
                                                            historyStore.addEntry(
                                                                firstImage: img,
                                                                carbEstimate: estimateString,
                                                                aiResultJSON: jsonForHistory
                                                            )
                                                        }
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
                                                    print("[RecipeAI] Error: \(error)")
                                                    
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
                                                        print("[RecipeCapture] ⚠️ Network interruption detected (likely due to backgrounding). Staying on loading screen.")
                                                        await MainActor.run {
                                                            // Don't set aiCompleted or navigate to error
                                                            // LoadingView will continue showing, user can dismiss via navigation if needed
                                                        }
                                                    } else {
                                                        // Rule: Error Handling - Show AI overload error for actual API errors
                                                        print("[RecipeCapture] ❌ Parsing/AI error - navigating to overload error view")
                                                        await MainActor.run {
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
                                                            goToOverloadError = true
                                                        }
                                                    }
                                                }
                                            } else {
                                                print("[RecipeAI] Missing recipe image")
                                                
                                                // Rule: State Management - Mark that we received a response
                                                hasReceivedResponse = true
                                                resultText = "{\"totalCarbGrams\":0,\"confidence\":1,\"recipeDescription\":\"Missing image\"}"
                                                
                                                // Still show success animation and navigate for missing image case
                                                print("[RecipeCapture] Image missing. Setting success state...")
                                                aiCompleted = true
                                                
                                                try? await Task.sleep(nanoseconds: 300_000_000)
                                                print("[RecipeCapture] Success animation complete, navigating to result screen")
                                                goToResult = true
                                            }
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            
                            // Recipe icon in upper-right (instead of step indicators)
                            HStack(spacing: 8) {
                                Image(systemName: "book.pages.fill")
                                    .font(.system(size: 25, weight: .semibold))
                                    .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                                    .accessibilityIdentifier("recipe-indicator")
                                    .accessibilityLabel("Recipe scan")
                            }
                            .padding(.top, 17)
                            .padding(.trailing, 10)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        }
                        .frame(width: geo.size.width, height: totalHeight * 0.25)
                        .background(.thinMaterial)
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 20,
                                bottomLeadingRadius: 0,
                                bottomTrailingRadius: 0,
                                topTrailingRadius: 20,
                                style: .continuous
                            )
                        )
                        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: -2)
                        .offset(y: -totalHeight * 0.25)
                        .zIndex(1)
                        .compositingGroup()
                        .accessibilityIdentifier("capture-area")
                        .ignoresSafeArea(edges: .bottom)
                    }
                    .ignoresSafeArea()
                }
            } else if auth == .denied || auth == .restricted {
                permissionDeniedView
            } else {
                ProgressView("Preparing camera…")
            }
        }
        .navigationDestination(isPresented: $goToLoading) {
            // Rule: SwiftUI-specific Patterns - Navigate to loading screen first
            LoadingView(aiCompleted: $aiCompleted, scanType: .recipe)
            .navigationDestination(isPresented: $goToResult) {
                // Once AI completes, navigate from loading to result
                // Rule: State Management - Nested navigation for loading -> result flow
                RecipeResultView(
                    resultText: $resultText,
                    isLoading: $isLoading,
                    recipeImage: storage.recipeImage, // Pass the captured image
                    onDone: {
                        print("[RecipeFlow] ResultView Done button tapped -> triggering full flow dismissal.")
                        onCancel()
                    }
                )
            }
            .navigationDestination(isPresented: $goToError) {
                // Rule: General Coding - Show error view when no content detected
                NoContentErrorView(errorType: .noRecipeInImages, onDismiss: {
                    print("[RecipeFlow] NoContentErrorView dismissed -> triggering full flow dismissal.")
                    onCancel()
                })
            }
            .navigationDestination(isPresented: $goToOverloadError) {
                // Rule: General Coding - Show overload error view for 503 errors
                AIOverloadErrorView(onDismiss: {
                    print("[RecipeFlow] AIOverloadErrorView dismissed -> triggering full flow dismissal.")
                    onCancel()
                })
            }
        }
        .onAppear {
            checkAndRequestCameraPermission { status in
                auth = status
                if status == .authorized {
                    // Only start if we are not already navigating away
                    if !goToLoading && !goToResult && !goToError && !goToOverloadError {
                        camera.start()
                    }
                }
            }
        }
        .onDisappear {
            // ✅ CRITICAL FIX - Stop camera IMMEDIATELY when view disappears
            // We call stop() directly (not in Task.detached) to ensure cleanup begins before navigation
            // The stop() method internally uses background thread to avoid blocking
            print("[Lifecycle] RecipeCaptureView disappeared, stopping camera...")
            camera.stop()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Rule: SwiftUI Lifecycle - Monitor scene phase to handle app backgrounding gracefully
            print("[RecipeCapture] Scene phase changed: \(oldPhase) -> \(newPhase)")
            
            if newPhase == .background {
                print("[RecipeCapture] 🌙 App entered background")
                
                // Rule: State Management - Track when we backgrounded
                if goToLoading && !hasReceivedResponse {
                    backgroundedAt = Date()
                    wasBackgrounded = true
                    print("[RecipeCapture] ⚠️ Loading screen backgrounded - request may be suspended by iOS")
                }
            }
            
            if newPhase == .active {
                print("[RecipeCapture] ☀️ App is now active")
                print("[RecipeCapture] State - goToLoading: \(goToLoading), goToResult: \(goToResult), aiCompleted: \(aiCompleted), hasReceivedResponse: \(hasReceivedResponse), wasBackgrounded: \(wasBackgrounded)")
                
                if oldPhase == .background {
                    print("[RecipeCapture] 🔄 App returned from background")
                    
                    // CRITICAL: If we were loading and backgrounded, we need to check the state immediately
                    if goToLoading && wasBackgrounded && !hasReceivedResponse {
                        let timeSinceBackground = backgroundedAt.map { Date().timeIntervalSince($0) } ?? 0
                        
                        print("[RecipeCapture] ⏱️ Time since background: \(String(format: "%.1f", timeSinceBackground))s")
                        
                        // Rule: Error Handling - iOS suspends network tasks after backgrounding
                        // Without a debugger attached, URLSession requests are often suspended
                        // and won't complete. We need to detect this and fail gracefully.
                        //
                        // AGGRESSIVE TIMEOUT: If backgrounded for >2 seconds without response,
                        // assume the request is stuck and won't complete.
                        if timeSinceBackground > 2.0 {
                            print("[RecipeCapture] ❌ Request suspended by iOS backgrounding (>2s) - cancelling and going back")
                            
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
                            print("[RecipeCapture] Going back to home screen")
                            DispatchQueue.main.async {
                                // Call onCancel to dismiss the entire flow
                                onCancel()
                            }
                            return
                        } else {
                            print("[RecipeCapture] ℹ️ Brief background (<2s), waiting for response...")
                        }
                    }
                    
                    // Rule: State Management - Check if we already have a result
                    // If aiCompleted is true, the AI finished while backgrounded - show results
                    if aiCompleted && resultText != nil && goToLoading && !goToResult && !goToError && !goToOverloadError {
                        print("[RecipeCapture] ✅ AI completed while backgrounded, triggering navigation to result")
                        // Trigger navigation by setting the flag
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            goToResult = true
                        }
                        return
                    }
                }
            }
        }
        .statusBarHidden(true)
        .navigationBarBackButtonHidden(true)
        // Rule: General Coding - Show classic Apple loading indicator during capture
        .overlay {
            if isCapturing {
                ZStack {
                    // Semi-transparent background
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    // Classic Apple loading indicator
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.2)
                }
                .transition(.opacity)
            }
        }
    }
    
    private func captureButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle().fill(Color.white).frame(width: 70, height: 70)
                Circle().stroke(Color.gray.opacity(0.4), lineWidth: 3).frame(width: 64, height: 64)
            }
            .shadow(radius: 2)
            .accessibilityLabel("Capture recipe photo")
            .accessibilityIdentifier("capture-button")
        }
    }
    
    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Text("Camera Access Needed").font(.headline)
            Text("Please allow camera access in Settings to capture recipe photos.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    /// Sanitizes JSON text by removing markdown fences and extracting the JSON object
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
}
// MARK: - Static Camera Preview (for Xcode Previews)
/// A static preview view that displays the "preview-camera" image from assets.
/// Used in Xcode previews where the actual camera hardware is unavailable.
/// Matches the behavior of AVCaptureVideoPreviewLayer with .resizeAspectFill gravity.
private struct StaticCameraPreview: View {
    var body: some View {
        GeometryReader { geo in
            Image("preview-camera")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .ignoresSafeArea()
        .accessibilityIdentifier("camera-preview")
    }
}

#Preview {
    // Use static image preview since camera hardware isn't available in Xcode previews
    // Wrap in NavigationStack to simulate the actual navigation context
    NavigationStack {
        GeometryReader { geo in
            let totalHeight = geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom
            
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    // Camera preview - full height
                    StaticCameraPreview()
                        .frame(height: totalHeight)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .background(Color.black)
                        .accessibilityIdentifier("camera-preview")
                    
                    // Top darkening gradient
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0.66),
                            Color.black.opacity(0.42),
                            Color.black.opacity(0.19),
                            Color.black.opacity(0.0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: geo.safeAreaInsets.top + totalHeight * 0.14)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    
                    // Description pill (centered)
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text("Scan ingredients page")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, geo.safeAreaInsets.top + totalHeight * 0.02)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("description-pill")
                    .accessibilityLabel("Capture instructions")
                    
                    // Leading close button
                    Button(action: {
                        print("[Preview] Close tapped")
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(10)
                    }
                    .background(.ultraThinMaterial, in: Circle())
                    .padding(.top, geo.safeAreaInsets.top + totalHeight * 0.02)
                    .padding(.leading, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("Close")
                    .accessibilityIdentifier("cancel-button")
                }
                
                // Bottom control area (white with rounded top corners)
                ZStack {
                    // Capture button centered
                    VStack(spacing: 0) {
                        Button(action: { print("[Preview] Capture tapped") }) {
                            ZStack {
                                Circle().fill(Color.white).frame(width: 70, height: 70)
                                Circle().stroke(Color.gray.opacity(0.4), lineWidth: 3).frame(width: 64, height: 64)
                            }
                            .shadow(radius: 2)
                            .accessibilityLabel("Capture recipe photo")
                            .accessibilityIdentifier("capture-button")
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    
                    // Recipe icon in upper-right (instead of step indicators)
                    HStack(spacing: 8) {
                        Image(systemName: "book.pages.fill")
                            .font(.system(size: 25, weight: .semibold))
                            .foregroundStyle(Color.black)
                            .accessibilityIdentifier("recipe-indicator")
                            .accessibilityLabel("Recipe scan")
                    }
                    .padding(.top, 17)
                    .padding(.trailing, 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
                .frame(width: geo.size.width, height: totalHeight * 0.25)
                .background(.thinMaterial)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 20,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 20,
                        style: .continuous
                    )
                )
                .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: -2)
                .offset(y: -totalHeight * 0.25)
                .zIndex(1)
                .compositingGroup()
                .accessibilityIdentifier("capture-area")
                .ignoresSafeArea(edges: .bottom)
            }
            .ignoresSafeArea()
        }
        .statusBarHidden(true)
        .navigationBarBackButtonHidden(true)
    }
    // Preview on an actual device size to get proper safe area insets
    .previewDevice(PreviewDevice(rawValue: "iPhone 15 Pro"))
    .previewDisplayName("Recipe Scan - iPhone 15 Pro")
}

