import Foundation
import SwiftUI
import UIKit
import Combine

// MARK: - Model
struct ScanEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let imageFilename: String
    let carbEstimate: String
    let date: Date
    // New: Persist the raw AI result JSON for re-opening full results later
    let aiResultJSON: String?
    let recipeURLString: String? // Optional: original recipe URL for link-based entries
}

// MARK: - Store
final class ScanHistoryStore: ObservableObject {
    // Note: Adding optional properties to ScanEntry maintains backward-compatible decoding for existing history files.
    private let cache = NSCache<NSString, UIImage>()
    @Published private(set) var entries: [ScanEntry] = []

    // Rule: General Coding - Increased from 10 to 500 to allow more history storage
    // Note: This does NOT affect the rotating background functionality for link-based recipes,
    // as that uses a persistent @AppStorage counter (linkBackgroundIndex) independent of entry count
    private let maxEntries = 500
    private let metadataFilename = "scan_history.json"

    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    private var metadataURL: URL {
        documentsURL.appendingPathComponent(metadataFilename)
    }

    init() {
        // Rule: Performance Optimization - Configure cache limits for efficient memory usage with 500 entries
        // totalCostLimit: ~100MB for cached images (reasonable for modern devices)
        // countLimit: Keep up to 50 most recently accessed images in memory
        cache.totalCostLimit = 100 * 1024 * 1024 // 100 MB
        cache.countLimit = 50 // Keep max 50 images in memory cache
        print("[History] Initialized with maxEntries=\(maxEntries), cache limits: 100MB/50 images")
        load()
    }

    /// Adds a new entry with the given first image, carb estimate string, and optional AI result JSON.
    /// - Parameter aiResultJSON: Raw JSON returned by AI for this scan. Persisted to allow re-opening full results.
    @MainActor
    func addEntry(firstImage: UIImage, carbEstimate: String, aiResultJSON: String? = nil, recipeURLString: String? = nil) {
        // 1) Save image to disk
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let filename = "scan_\(iso.string(from: Date()).replacingOccurrences(of: ":", with: "-")).jpg"
        let imageURL = documentsURL.appendingPathComponent(filename)
        if let data = firstImage.jpegData(compressionQuality: 0.85) {
            do {
                try data.write(to: imageURL, options: .atomic)
                // Optionally exclude from iCloud backup if desired in the future
            } catch {
                print("[History] Failed to write image: \(error)")
            }
        }

        // 2) Append metadata at the front (most recent first)
        let entry = ScanEntry(
            id: UUID(),
            imageFilename: filename,
            carbEstimate: carbEstimate,
            date: Date(),
            aiResultJSON: aiResultJSON,
            recipeURLString: recipeURLString
        )
        entries.insert(entry, at: 0)
        print("[History] Added entry. hasAIJSON=\(aiResultJSON != nil) filename=\(filename)")

        // 3) Trim and remove old images
        if entries.count > maxEntries {
            let overflow = entries.suffix(from: maxEntries)
            entries = Array(entries.prefix(maxEntries))
            for e in overflow {
                let url = documentsURL.appendingPathComponent(e.imageFilename)
                try? FileManager.default.removeItem(at: url)
            }
        }

        // 4) Persist metadata
        save()
    }

    func image(for entry: ScanEntry) -> UIImage? {
        let key = entry.imageFilename as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        let url = documentsURL.appendingPathComponent(entry.imageFilename)
        if let image = UIImage(contentsOfFile: url.path) {
            // Rule: Performance Optimization - Cache with cost tracking for efficient memory management
            // Estimate cost based on image dimensions (width * height * 4 bytes per pixel)
            let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
            cache.setObject(image, forKey: key, cost: cost)
            return image
        }
        return nil
    }

    private func load() {
        do {
            let data = try Data(contentsOf: metadataURL)
            let decoded = try JSONDecoder().decode([ScanEntry].self, from: data)
            // Ensure most recent first by date
            entries = decoded.sorted(by: { $0.date > $1.date })
        } catch {
            entries = []
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: metadataURL, options: .atomic)
        } catch {
            print("[History] Failed to save metadata: \(error)")
        }
    }
}
