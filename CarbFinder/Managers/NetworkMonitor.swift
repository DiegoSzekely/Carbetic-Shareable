//
//  NetworkMonitor.swift
//  CarbFinder
//
//  Network connectivity monitor using NWPathMonitor
//  Rule: General Coding - Use native Network framework for reliable connectivity detection
//

import Foundation
import Network
import Combine

/// Monitors network connectivity status using NWPathMonitor
/// Rule: State Management - ObservableObject allows SwiftUI views to react to connectivity changes
class NetworkMonitor: ObservableObject {
    /// Current network connectivity status
    /// Rule: SwiftUI-specific Patterns - @Published triggers view updates
    @Published private(set) var isConnected: Bool = true
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    init() {
        startMonitoring()
    }
    
    /// Starts monitoring network path changes
    /// Rule: General Coding - Monitor runs on background queue to avoid blocking main thread
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let connected = path.status == .satisfied
                self?.isConnected = connected
                print("[NetworkMonitor] Connectivity changed: \(connected ? "Connected" : "Disconnected")")
            }
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}
