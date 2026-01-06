import Foundation
import UIKit

/// Minimal client for Gemini AI (multimodal) using the Generative Language API.
/// Model name and API key are dynamically fetched from Firebase Remote Config, allowing updates without app releases.
/// Sends images (as JPEG base64) and/or URL context with a prompt, returns the model's text response.
/// Rule: General Coding - Use background URLSession to handle app backgrounding during long AI requests
struct GeminiClient {
    /// Endpoint URL - now dynamically constructed based on Firebase Remote Config
    /// Rule: General Coding - Use AIModelConfigManager for centralized model configuration
    private var endpoint: URL {
        AIModelConfigManager.shared.getEndpointURL()
    }
    
    /// Background URLSession configuration for long-running requests
    /// Rule: Performance Optimization - Use default session with extended timeout
    /// Note: We use .default (not .background or .ephemeral) because:
    /// - .background requires delegate-based uploads and complex state management
    /// - .ephemeral doesn't survive app backgrounding on real devices (without debugger)
    /// - .default with extended timeout is the most reliable for brief backgrounding
    /// Limitation: Still won't survive if iOS terminates the app or extended backgrounding (>30s)
    private static let backgroundSession: URLSession = {
        let config = URLSessionConfiguration.default
        // Extended timeout for long AI processing (2 minutes)
        config.timeoutIntervalForRequest = 120.0
        config.timeoutIntervalForResource = 120.0
        // Allow cellular data
        config.allowsCellularAccess = true
        // Use waitsForConnectivity to handle temporary network issues
        config.waitsForConnectivity = true
        // Prevent iOS from aggressively suspending network tasks
        config.isDiscretionary = false
        return URLSession(configuration: config)
    }()

    /// Sends images + prompt. Returns the raw text from the first candidate, or error.
    /// - Parameters:
    ///   - images: Array of UIImages to send (will be converted to JPEG base64)
    ///   - prompt: Text prompt for the AI
    ///   - url: Optional URL for grounding (Gemini will fetch and use content from this URL)
    func send(images: [UIImage], prompt: String, url: URL? = nil) async throws -> String {
        // Build parts: alternating inline image data and a text prompt
        var parts: [[String: Any]] = []
        
        // Add images (up to 3)
        for img in images.prefix(3) {
            guard let jpeg = img.jpegData(compressionQuality: 0.9) else { continue }
            let b64 = jpeg.base64EncodedString()
            parts.append([
                "inline_data": [
                    "mime_type": "image/jpeg",
                    "data": b64
                ]
            ])
        }
        
        // Add text prompt
        parts.append(["text": prompt])

        // Build request body
        var body: [String: Any] = [
            "contents": [
                ["parts": parts]
            ]
        ]
        
        // Add URL context grounding if URL is provided
        if let url = url {
            print("[Gemini] Enabling URL context grounding for: \(url.absoluteString)")
            body["tools"] = [
                [
                    "urlContext": [
                        "url": url.absoluteString
                    ]
                ]
            ]
        }

        var request = URLRequest(url: endpoint.appending(queryItems: [URLQueryItem(name: "key", value: AIModelConfigManager.shared.apiKey)]))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        print("[Gemini] Using model: \(AIModelConfigManager.shared.currentModelName)") // Rule: General Coding - Log which model is being used
        print("[Gemini] Using API key length: \(AIModelConfigManager.shared.apiKey.count) chars") // Rule: General Coding - Log API key length without exposing it
        print("[Gemini] Sending request with \(images.prefix(3).count) images, body size: \(request.httpBody?.count ?? 0) bytes")
        
        // Rule: General Coding - Use background-compatible session with extended timeout
        // Wrap in withCheckedThrowingContinuation to handle backgrounding properly
        return try await withCheckedThrowingContinuation { continuation in
            let task = Self.backgroundSession.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("[Gemini] Error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let data = data, let response = response else {
                    print("[Gemini] No data or response")
                    continuation.resume(throwing: URLError(.badServerResponse))
                    return
                }
                
                guard let http = response as? HTTPURLResponse else {
                    print("[Gemini] Invalid response type")
                    continuation.resume(throwing: URLError(.badServerResponse))
                    return
                }
                
                guard (200..<300).contains(http.statusCode) else {
                    let text = String(data: data, encoding: .utf8) ?? "<no body>"
                    print("[Gemini] HTTP \(http.statusCode): \(text)")
                    let error = NSError(domain: "Gemini", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: text])
                    continuation.resume(throwing: error)
                    return
                }
                
                // Parse the candidate's text
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                    let candidates = (json?["candidates"] as? [[String: Any]]) ?? []
                    guard let first = candidates.first,
                          let content = first["content"] as? [String: Any],
                          let partsArray = content["parts"] as? [[String: Any]] else {
                        let fallback = String(data: data, encoding: .utf8) ?? ""
                        print("[Gemini] Unexpected response shape. Returning raw body.")
                        continuation.resume(returning: fallback)
                        return
                    }
                    
                    let text = partsArray.compactMap { $0["text"] as? String }.joined(separator: "\n")
                    print("[Gemini] Received text length: \(text.count)")
                    continuation.resume(returning: text)
                } catch {
                    print("[Gemini] JSON parsing error: \(error)")
                    continuation.resume(throwing: error)
                }
            }
            
            task.resume()
        }
    }
}

private extension URL {
    func appending(queryItems: [URLQueryItem]) -> URL {
        guard var comps = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return self }
        comps.queryItems = (comps.queryItems ?? []) + queryItems
        return comps.url ?? self
    }
}
