import SwiftUI
import AVFoundation
import UIKit
import Combine

// MARK: - Camera Permission Helper
enum CameraAuthorizationStatus {
    case authorized, denied, restricted, notDetermined
}

func checkAndRequestCameraPermission(completion: @escaping (CameraAuthorizationStatus) -> Void) {
    let status = AVCaptureDevice.authorizationStatus(for: .video)
    switch status {
    case .authorized:
        print("[Permissions] Camera already authorized")
        completion(.authorized)
    case .notDetermined:
        print("[Permissions] Requesting camera permission…")
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                completion(granted ? .authorized : .denied)
                print("[Permissions] User responded: \(granted ? "granted" : "denied")")
            }
        }
    case .denied:
        print("[Permissions] Camera denied previously")
        completion(.denied)
    case .restricted:
        print("[Permissions] Camera restricted")
        completion(.restricted)
    @unknown default:
        completion(.denied)
    }
}

// MARK: - Capture Session Coordinator (no Combine)
final class CaptureSessionCoordinator: NSObject, ObservableObject {
    private let sessionQueue = DispatchQueue(label: "com.carbfinder.camera.session")
    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    @Published private var isConfigured = false

    private var activePhotoDelegates: [NSObject] = [] // retain delegates until callbacks finish

    override init() {
        super.init()
        print("[Camera] Coordinator init")
    }

    deinit {
        print("[Camera] Coordinator deinit")
        sessionQueue.sync {
            if self.session.isRunning {
                print("[Camera] deinit: stopping running session")
                self.session.stopRunning()
            }
        }
    }

    func configureIfNeeded() {
        guard !isConfigured else { return }
        session.beginConfiguration()
        // Rule: Performance - Use .high preset for smooth preview (8-10MP)
        // This gives excellent preview quality without the overhead of .photo preset
        session.sessionPreset = .high
        // Input
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("[Camera] Failed to get back camera")
            session.commitConfiguration()
            return
        }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) { session.addInput(input) }
        } catch {
            print("[Camera] Error creating device input: \(error)")
            session.commitConfiguration()
            return
        }
        // Output
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        // Rule: Performance - Disable high-res capture to reduce file size & processing time
        // Standard resolution is more than sufficient for AI analysis
        photoOutput.isHighResolutionCaptureEnabled = false
        session.commitConfiguration()
        isConfigured = true
        print("[Camera] Session configured with .high preview, standard resolution capture")
    }

    func start() {
        configureIfNeeded()
        print("[Camera] Starting session (request)")
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            guard !self.session.isRunning else {
                print("[Camera] Session already running")
                return
            }
            print("[Camera] Starting session on sessionQueue…")
            self.session.startRunning()
            print("[Camera] Session isRunning=\(self.session.isRunning)")
        }
    }

    func stop() {
        print("[Camera] Stopping session requested")
        sessionQueue.sync {
            if self.session.isRunning {
                print("[Camera] Calling stopRunning() synchronously on sessionQueue…")
                self.session.stopRunning()
                print("[Camera] Session stopped, isRunning=\(self.session.isRunning)")
            } else {
                print("[Camera] Session already stopped")
            }
        }
    }

    func makePreviewLayer() -> AVCaptureVideoPreviewLayer {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }

    func capture(completion: @escaping (UIImage?) -> Void) {
        // ✅ Ensure session is running before capturing
        guard session.isRunning else {
            print("[Camera] ❌ Cannot capture - session is not running")
            completion(nil)
            return
        }
        
        
        let settings = AVCapturePhotoSettings()

        // CHECK before setting!
        // The photoOutput knows exactly what the current device's camera can do.
        if photoOutput.supportedFlashModes.contains(.auto) {
            settings.flashMode = .auto
        } else {
            // If the device (like iPad Air) has no flash, we must set it to .off
            settings.flashMode = .off
        }

        // Create an identifier we can use to remove the delegate later without capturing it prematurely
        var delegateRef: PhotoCaptureDelegate?
        let removeDelegate: () -> Void = { [weak self] in
            guard let self = self, let delegateRef = delegateRef else { return }
            if let idx = self.activePhotoDelegates.firstIndex(where: { ObjectIdentifier($0) == ObjectIdentifier(delegateRef) }) {
                self.activePhotoDelegates.remove(at: idx)
            }
        }

        let newDelegate = PhotoCaptureDelegate { data in
            DispatchQueue.main.async {
                if let data = data, let image = UIImage(data: data) {
                    print("[Camera] Photo captured, size: \(data.count) bytes")
                    completion(image)
                } else {
                    print("[Camera] Failed to capture photo")
                    completion(nil)
                }
                removeDelegate()
            }
        }

        delegateRef = newDelegate
        activePhotoDelegates.append(newDelegate)
        print("[Camera] Capturing photo…")
        photoOutput.capturePhoto(with: settings, delegate: newDelegate)
    }

    // Internal delegate helper
    private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
        private let handler: (Data?) -> Void
        init(_ handler: @escaping (Data?) -> Void) { self.handler = handler }
        func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
            if let error = error { print("[Camera] Photo processing error: \(error)") }
            handler(photo.fileDataRepresentation())
        }
    }
}

// MARK: - CameraPreview (UIKit host)
struct CameraPreview: UIViewControllerRepresentable {
    let coordinator: CaptureSessionCoordinator

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = PreviewHostViewController()
        vc.previewLayer = coordinator.makePreviewLayer()
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    final class PreviewHostViewController: UIViewController {
        var previewLayer: AVCaptureVideoPreviewLayer?
        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            view.backgroundColor = .clear
            if let layer = previewLayer {
                if layer.superlayer == nil { view.layer.addSublayer(layer) }
                layer.frame = view.bounds
            }
        }
        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            if let layer = previewLayer {
                print("[CameraPreview] Detaching preview layer from session")
                layer.session = nil
                layer.removeFromSuperlayer()
            }
        }
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

// MARK: - Simple in-memory storage (no observation required now)
final class CaptureStorage {
    var image1: UIImage? { didSet { print("[Storage] image1 set: \(image1 != nil)") } }
    var image2: UIImage? { didSet { print("[Storage] image2 set: \(image2 != nil)") } }
    var image3: UIImage? { didSet { print("[Storage] image3 set: \(image3 != nil)") } }
    var userComment: String? { didSet { print("[Storage] userComment set: \(userComment ?? "nil")") } } // Rule: State Management - Store user comment in shared storage

    /// Resets all stored images and comment to nil.
    func clear() {
        image1 = nil
        image2 = nil
        image3 = nil
        userComment = nil
        print("[Storage] All images and comment cleared")
    }
}

// Helper shape to round only the top corners of the capture area
private struct TopRoundedCorners: Shape {
    var radius: CGFloat = 25
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = min(min(radius, rect.width / 2), rect.height / 2)
        // Start at left edge below the top-left corner radius
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + r))
        // Top-left corner
        path.addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r),
                    radius: r,
                    startAngle: .degrees(180),
                    endAngle: .degrees(270),
                    clockwise: false)
        // Top edge to top-right corner
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        // Top-right corner
        path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r),
                    radius: r,
                    startAngle: .degrees(270),
                    endAngle: .degrees(0),
                    clockwise: false)
        // Right edge down to bottom-right
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        // Bottom edge to bottom-left
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        // Close path back to start
        path.closeSubpath()
        return path
    }
}

// MARK: - Comment Input Sheet
/// Minimalistic sheet for entering optional AI guidance comment
/// Rule: General Coding - Apple native design, optimized for light & dark mode
private struct CommentInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var comment: String
    @FocusState private var isTextFieldFocused: Bool // Rule: SwiftUI-specific Patterns - Use FocusState for keyboard management
    
    // Suggestion pills data
    private let suggestions: [(title: String, text: String)] = [
        ("Sweeteners", "baked/cooked using sweeteners"),
        ("Extra sweet", "Contains more sugar than typical for this meal"),
        ("Low carb substitute", "Made with low-carb alternatives")
    ]
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                // Title section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add note (optional)")
                        .font(.title.weight(.bold)) // Rule: General Coding - Larger title as requested
                        .foregroundStyle(.primary)
                    
                    Text("Help the AI understand special details about your meal")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
                
                // Text field with example and clear button
                VStack(alignment: .leading, spacing: 8) {
                    ZStack(alignment: .topTrailing) {
                        TextField("e.g., baked using sweeteners", text: $comment, axis: .vertical)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .padding(.trailing, !comment.isEmpty ? 32 : 0) // Add padding when clear button is visible
                            .focused($isTextFieldFocused)
                            .lineLimit(3...6) // Rule: General Coding - Allow multi-line but cap at reasonable height
                            .accessibilityIdentifier("comment-textfield")
                        
                        // Clear button - only shows when text exists
                        // Rule: General Coding - Clear button in top-right corner with gray color
                        if !comment.isEmpty {
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                comment = ""
                                print("[UI] Comment cleared")
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.secondary) // Gray color as requested
                            }
                            .padding(.top, 10)
                            .padding(.trailing, 10)
                            .accessibilityLabel("Clear text")
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(.quaternary, lineWidth: 1)
                    )
                    .animation(.easeInOut(duration: 0.2), value: comment.isEmpty)
                }
                
                // Suggestion pills section
                // Rule: General Coding - Beautiful, interactive suggestion pills with subtle styling
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick suggestions")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    
                    FlowLayout(spacing: 8) {
                        ForEach(suggestions, id: \.title) { suggestion in
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                // Add suggestion text to comment
                                if comment.isEmpty {
                                    comment = suggestion.text
                                } else {
                                    comment += ", " + suggestion.text
                                }
                                print("[UI] Added suggestion: \(suggestion.text)")
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 14))
                                    Text(suggestion.title)
                                        .font(.subheadline.weight(.medium))
                                }
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.secondary.opacity(0.15), in: Capsule()) // Rule: General Coding - Subtle gray instead of blue
                            }
                            .accessibilityLabel("Add \(suggestion.title)")
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    }
                    .accessibilityIdentifier("comment-cancel-button")
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        print("[UI] Comment saved: \(comment.isEmpty ? "(empty)" : comment)")
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("comment-done-button")
                }
            }
            .onAppear {
                // Rule: SwiftUI Lifecycle - Auto-focus text field when sheet appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isTextFieldFocused = true
                }
            }
        }
        .presentationDetents([.large]) // Rule: General Coding - Large (almost full screen) as requested
        .presentationDragIndicator(.hidden) // Rule: General Coding - Hide handle as requested
    }
}

// MARK: - FlowLayout Helper
/// Simple flow layout for wrapping suggestion pills
/// Rule: SwiftUI-specific Patterns - Custom layout for dynamic pill wrapping
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

// MARK: - Base capture view building block
private struct CaptureScaffold<Controls: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let step: Int
    let preview: AnyView
    let onCancel: () -> Void
    let onInfo: () -> Void
    let onAddNote: () -> Void // Rule: General Coding - Callback for note button
    let hasNote: Bool // Rule: State Management - Visual indicator for existing note
    @ViewBuilder var controls: Controls

    var body: some View {
        GeometryReader { geo in
            let totalHeight = geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom

            // We compute sizes using the full screen height (including safe area insets)
            // and ignore safe areas on the whole container so the two parts meet perfectly
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    // Top 70%: Live camera preview - fixed height to avoid any in-between gaps
                    preview
                        .frame(height: totalHeight)  // changed from totalHeight * 0.8 to totalHeight
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .background(Color.black) // Ensures no seams under content
                        .accessibilityIdentifier("camera-preview")

                    // Top darkening gradient to improve contrast for the pill and cancel button
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0.66), // darkest at very top
                            Color.black.opacity(0.42),
                            Color.black.opacity(0.19),
                            Color.black.opacity(0.0)   // fades out beneath the pill/cancel
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    // Height chosen to extend just beneath the description pill and cancel button
                    .frame(height: geo.safeAreaInsets.top + totalHeight * 0.14)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                    // Description pill - now non-clickable
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(title)
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    // Centered horizontally and positioned beneath the notch/dynamic island with 2% of the screen height spacing
                    .padding(.top, geo.safeAreaInsets.top + totalHeight * 0.02)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("description-pill")
                    .accessibilityLabel("Capture instructions")

                    // Leading close control with the same liquid glass effect as the pill
                    Button(action: {
                        print("[UI] Close tapped")
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onCancel()
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

                    // Trailing question control with the same liquid glass effect as the pill
                    Button(action: {
                        print("[UI] Question mark tapped")
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onInfo()
                    }) {
                        Image(systemName: "questionmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(10)
                    }
                    .background(.ultraThinMaterial, in: Circle())
                    .padding(.top, geo.safeAreaInsets.top + totalHeight * 0.02)
                    .padding(.trailing, 20)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .accessibilityLabel("Help")
                    .accessibilityIdentifier("help-button")
                }

                // Bottom 30%: White control area with capture button - fixed height to perfectly meet the preview above
                ZStack {
                    // Controls content centered in the capture area
                    VStack(spacing: 0) {
                        controls
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                    // Beautiful note button in the upper-left corner
                    // Rule: General Coding - Beautiful button design without extra material (sits on existing material background)
                    Button(action: {
                        print("[UI] Add note button tapped")
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onAddNote()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: hasNote ? "note.text" : "note.text")
                                .font(.system(size: 16, weight: .semibold))
                                .symbolRenderingMode(.hierarchical)
                            Text(hasNote ? "Edit note" : "Add note")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(hasNote ? Color.accentColor : Color.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            // Rule: General Coding - Adjusted prominence: empty more visible, filled more subtle
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(hasNote ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(hasNote ? Color.accentColor.opacity(0.2) : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .padding(.top, 17)
                    .padding(.leading, 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .accessibilityLabel(hasNote ? "Edit note" : "Add note")
                    .accessibilityIdentifier("add-note-button")

                    // Step indicators in the upper-right corner
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { index in
                            let current = index + 1
                            let name: String = {
                                if current < step { return "photo.badge.checkmark.fill" }
                                // active and upcoming both show plain photo
                                return "photo.fill"
                            }()
                            Image(systemName: name)
                                .font(.system(size: 25, weight: .semibold))
                                .foregroundStyle(
                                    name == "photo.badge.checkmark.fill"
                                    ? (colorScheme == .dark ? Color.white : Color.black)
                                    : Color.gray
                                )
                                .accessibilityIdentifier("capture-progress-\(current)")
                                .accessibilityLabel("Capture step \(current)")
                        }
                    }
                    .padding(.top, 17)
                    .padding(.trailing, 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
                .frame(width: geo.size.width, height: totalHeight * 0.25) // changed from totalHeight * 0.20 to totalHeight * 0.25
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
                // Cast shadow upward so it overlays the preview beneath
                .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: -2)
                .offset(y: -totalHeight * 0.25) // changed from -totalHeight * 0.05 to -totalHeight * 0.25
                .zIndex(1) // Ensure it renders above the preview
                .compositingGroup()
                .accessibilityIdentifier("capture-area")
                .ignoresSafeArea(edges: .bottom) // Extend behind home indicator with white
            }
            .ignoresSafeArea() // Allow the whole container to extend into safe areas
        }
    }
}

// MARK: - Capture1View
struct Capture1View: View {
    let storage: CaptureStorage
    let onCancel: () -> Void
    let historyStore: ScanHistoryStore
    let usageManager: CaptureUsageManager // Rule: State Management - Pass usage manager through
    @State private var auth: CameraAuthorizationStatus = .notDetermined
    @StateObject private var camera = CaptureSessionCoordinator()
    @State private var navigateNext = false
    @State private var showingHowTo = false
    @State private var showingCommentSheet = false // Rule: State Management - Local state for sheet presentation
    @State private var userComment: String = "" // Rule: State Management - Local state for comment text
    @State private var isCapturing = false // Rule: State Management - Track capture in progress for loading indicator
    
    /// Helper to handle cancel action - stops camera before dismissing
    /// Rule: General Coding - Ensure cleanup happens before navigation for smooth UX
    private func handleCancel() {
        print("[UI] Capture1 cancel requested - stopping camera first")
        camera.stop() // Stop camera immediately
        onCancel() // Then dismiss
    }

    var body: some View {
        ZStack {
            if auth == .authorized {
                CaptureScaffold(title: "Scan from above", step: 1,
                                preview: AnyView(CameraPreview(coordinator: camera)),
                                onCancel: handleCancel, // Use helper that stops camera first
                                onInfo: { 
                                    print("[Sheet] Presenting HowToCaptureSheet from Capture1View")
                                    showingHowTo = true
                                },
                                onAddNote: {
                                    print("[Sheet] Presenting CommentInputSheet from Capture1View")
                                    showingCommentSheet = true
                                },
                                hasNote: !userComment.isEmpty) {
                    captureButton {
                        print("[UI] Capture1 button tapped")
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        
                        // Rule: General Coding - Show loading indicator during capture
                        isCapturing = true
                        
                        camera.capture { image in
                            // Rule: General Coding - Always hide loading indicator in completion
                            isCapturing = false
                            
                            if let img = image { 
                                storage.image1 = img
                                // Rule: State Management - Save comment to storage before navigating
                                if !userComment.isEmpty {
                                    storage.userComment = userComment
                                }
                                print("[Flow] Capture1 complete. Stopping camera before navigation…")
                                camera.stop()
                                navigateNext = true
                            } else {
                                // Rule: General Coding - Handle capture failure gracefully
                                print("[UI] ❌ Capture failed - session may have been stopped")
                                // Don't navigate if capture failed
                            }
                        }
                    }
                }
            } else if auth == .denied || auth == .restricted {
                permissionDeniedView
            } else {
                ProgressView("Preparing camera…")
            }
        }
        .navigationDestination(isPresented: $navigateNext) {
            Capture2View(storage: storage, onCancel: onCancel, historyStore: historyStore, usageManager: usageManager)
        }
        .sheet(isPresented: $showingHowTo) {
            HowToCaptureSheet()
                .presentationDetents([.large])
                .interactiveDismissDisabled(true)
        }
        .sheet(isPresented: $showingCommentSheet) {
            // Rule: SwiftUI-specific Patterns - Use @Binding for two-way data flow
            CommentInputSheet(comment: $userComment)
        }
        .onAppear {
            // Rule: State Management - Load existing comment from storage if available
            if let existingComment = storage.userComment {
                userComment = existingComment
            }
            
            checkAndRequestCameraPermission { status in
                auth = status
                if status == .authorized {
                    // Only start if we are not already navigating away
                    if !navigateNext {
                        camera.start()
                    }

                    // Auto-present HowToCaptureSheet after camera loads for the first two completed scans ever
                    // Rule: General Coding - Add debug logs; SwiftUI Lifecycle - onAppear timing; State Management - local @State flag
                    let shouldAutoPresent = historyStore.entries.count < 2
                    if shouldAutoPresent {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [auth] in
                            // Ensure camera is authorized and sheet isn't already visible
                            if auth == .authorized && showingHowTo == false {
                                print("[Sheet] Auto-present HowToCaptureSheet (first two scans). entries=\(historyStore.entries.count)")
                                showingHowTo = true
                            }
                        }
                    }
                    
                    // Rule: Push Notifications - Request permissions on 7th capture attempt (when entries.count >= 6)
                    // This ensures user has used the app and understands the value before requesting notifications
                    if historyStore.entries.count >= 6 {
                        print("[Notifications] 7th capture detected, requesting permissions (entries: \(historyStore.entries.count))")
                        AnalysisNotificationManager.shared.requestPermissionsIfNeeded()
                    } else {
                        print("[Notifications] Not yet 7th capture, skipping permission request (entries: \(historyStore.entries.count))")
                    }
                }
            }
        }
        .onDisappear {
            // ✅ CRITICAL FIX - Stop camera IMMEDIATELY when view disappears
            // We call stop() directly (not in Task.detached) to ensure cleanup begins before navigation
            // The stop() method internally uses background thread to avoid blocking
            print("[Lifecycle] Capture1View disappeared, stopping camera...")
            camera.stop()
        }
        // Hide system status bar while capturing
        .statusBarHidden(true)
        .navigationBarBackButtonHidden(true)
        // Rule: General Coding - Show minimal Apple-style loading indicator during capture
        .overlay {
            if isCapturing {
                ZStack {
                    // Semi-transparent background
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    // Classic Apple loading indicator
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.5)
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
            .accessibilityLabel("Capture photo")
            .accessibilityIdentifier("capture-button")
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Text("Camera Access Needed").font(.headline)
            Text("Please allow camera access in Settings to capture meal photos.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }.buttonStyle(.borderedProminent)
        }.padding()
    }
}

// MARK: - Capture2View
struct Capture2View: View {
    let storage: CaptureStorage
    let onCancel: () -> Void
    let historyStore: ScanHistoryStore
    let usageManager: CaptureUsageManager // Rule: State Management - Pass usage manager through
    @StateObject private var camera = CaptureSessionCoordinator()
    @State private var auth: CameraAuthorizationStatus = .notDetermined
    @State private var navigateNext = false
    @State private var showingHowTo = false
    @State private var showingCommentSheet = false // Rule: State Management - Local state for sheet presentation
    @State private var userComment: String = "" // Rule: State Management - Local state for comment text
    @State private var isCapturing = false // Rule: State Management - Track capture in progress for loading indicator
    
    /// Helper to handle cancel action - stops camera before dismissing
    /// Rule: General Coding - Ensure cleanup happens before navigation for smooth UX
    private func handleCancel() {
        print("[UI] Capture2 cancel requested - stopping camera first")
        camera.stop() // Stop camera immediately
        onCancel() // Then dismiss
    }

    var body: some View {
        ZStack {
            if auth == .authorized {
                CaptureScaffold(title: "Slight angle (45°)", step: 2,
                                preview: AnyView(CameraPreview(coordinator: camera)),
                                onCancel: handleCancel, // Use helper that stops camera first
                                onInfo: {
                                    print("[Sheet] Presenting HowToCaptureSheet from Capture2View")
                                    showingHowTo = true
                                },
                                onAddNote: {
                                    print("[Sheet] Presenting CommentInputSheet from Capture2View")
                                    showingCommentSheet = true
                                },
                                hasNote: !userComment.isEmpty) {
                    captureButton {
                        print("[UI] Capture2 button tapped")
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        
                        // Rule: General Coding - Show loading indicator during capture
                        isCapturing = true
                        
                        camera.capture { image in
                            // Rule: General Coding - Always hide loading indicator in completion
                            isCapturing = false
                            
                            if let img = image { 
                                storage.image2 = img
                                // Rule: State Management - Save comment to storage before navigating
                                if !userComment.isEmpty {
                                    storage.userComment = userComment
                                }
                                print("[Flow] Capture2 complete. Stopping camera before navigation…")
                                camera.stop()
                                navigateNext = true
                            } else {
                                // Rule: General Coding - Handle capture failure gracefully
                                print("[UI] ❌ Capture failed - session may have been stopped")
                                // Don't navigate if capture failed
                            }
                        }
                    }
                }
            } else if auth == .denied || auth == .restricted {
                permissionDeniedView
            } else {
                ProgressView("Preparing camera…")
            }
        }
        .navigationDestination(isPresented: $navigateNext) {
            Capture3View(storage: storage, onCancel: onCancel, historyStore: historyStore, usageManager: usageManager)
        }
        .sheet(isPresented: $showingHowTo) {
            HowToCaptureSheet()
                .presentationDetents([.large])
                .interactiveDismissDisabled(true)
        }
        .sheet(isPresented: $showingCommentSheet) {
            // Rule: SwiftUI-specific Patterns - Use @Binding for two-way data flow
            CommentInputSheet(comment: $userComment)
        }
        .onAppear {
            // Rule: State Management - Load existing comment from storage if available
            if let existingComment = storage.userComment {
                userComment = existingComment
            }
            
            checkAndRequestCameraPermission { status in
                auth = status
                if status == .authorized {
                    // Only start if we are not already navigating away
                    if !navigateNext {
                        camera.start()
                    }
                }
                print("[Lifecycle] \(String(describing: Self.self)) appeared, session started: \(status == .authorized)")
            }
        }
        .onDisappear {
            // ✅ CRITICAL FIX - Stop camera IMMEDIATELY when view disappears
            // We call stop() directly (not in Task.detached) to ensure cleanup begins before navigation
            // The stop() method internally uses background thread to avoid blocking
            print("[Lifecycle] Capture2View disappeared, stopping camera...")
            camera.stop()
        }
        .statusBarHidden(true)
        .navigationBarBackButtonHidden(true)
        // Rule: General Coding - Show minimal Apple-style loading indicator during capture
        .overlay {
            if isCapturing {
                ZStack {
                    // Semi-transparent background
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    // Classic Apple loading indicator
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.5)
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
            .accessibilityLabel("Capture photo")
            .accessibilityIdentifier("capture-button")
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Text("Camera Access Needed").font(.headline)
            Text("Please allow camera access in Settings to capture meal photos.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }.buttonStyle(.borderedProminent)
        }.padding()
    }
}

// MARK: - Capture3View
// Updated to navigate to ResultView and perform Gemini call after third capture.
struct Capture3View: View {
    let storage: CaptureStorage
    let onCancel: () -> Void // This closure effectively dismisses the whole flow from ContentView
    let historyStore: ScanHistoryStore
    let usageManager: CaptureUsageManager // Rule: State Management - Pass usage manager for tracking
    @StateObject private var camera = CaptureSessionCoordinator()
    @State private var auth: CameraAuthorizationStatus = .notDetermined

    @State private var goToLoading = false
    @State private var goToResult = false
    @State private var goToError = false // Rule: General Coding - Navigate to error view when no content detected
    @State private var goToOverloadError = false // Rule: General Coding - Navigate to overload error view for 503
    @State private var aiCompleted = false // Rule: State Management - Separate state for triggering success animation
    @State private var resultText: String? = nil
    @State private var isLoading: Bool = false
    @State private var showingHowTo = false
    @State private var showingCommentSheet = false // Rule: State Management - Local state for sheet presentation
    @State private var userComment: String = "" // Rule: State Management - Local state for comment text
    @State private var aiRequestTask: Task<Void, Never>? = nil // Rule: State Management - Hold reference to AI task for cancellation
    @State private var hasReceivedResponse = false // Rule: State Management - Track if we've received ANY response (success or error)
    @State private var backgroundedAt: Date? = nil // Rule: State Management - Track when app was backgrounded to detect timeouts
    @State private var requestStartedAt: Date? = nil // Rule: State Management - Track when request started for overall timeout
    @State private var wasBackgrounded = false // Rule: State Management - Track if we've been backgrounded during this loading session
    @State private var isCapturing = false // Rule: State Management - Track capture in progress for loading indicator
    
    // Rule: SwiftUI Lifecycle - Monitor app lifecycle to handle backgrounding gracefully
    @Environment(\.scenePhase) private var scenePhase
    
    /// Helper to handle cancel action - stops camera before dismissing
    /// Rule: General Coding - Ensure cleanup happens before navigation for smooth UX
    private func handleCancel() {
        print("[UI] Capture3 cancel requested - stopping camera first")
        camera.stop() // Stop camera immediately
        onCancel() // Then dismiss
    }

    var body: some View {
        ZStack {
            if auth == .authorized {
                CaptureScaffold(title: "Side (near 0°)", step: 3,
                                preview: AnyView(CameraPreview(coordinator: camera)),
                                onCancel: handleCancel, // Use helper that stops camera first
                                onInfo: {
                                    print("[Sheet] Presenting HowToCaptureSheet from Capture3View")
                                    showingHowTo = true
                                },
                                onAddNote: {
                                    print("[Sheet] Presenting CommentInputSheet from Capture3View")
                                    showingCommentSheet = true
                                },
                                hasNote: !userComment.isEmpty) {
                    captureButton {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        
                        // Rule: General Coding - Show loading indicator during capture
                        isCapturing = true
                        
                        camera.capture { image in
                            // Rule: General Coding - Always hide loading indicator in completion
                            isCapturing = false
                            
                            if let img = image { 
                                storage.image3 = img
                                // Rule: State Management - Save comment to storage before navigating
                                if !userComment.isEmpty {
                                    storage.userComment = userComment
                                }
                            } else {
                                // Rule: General Coding - Handle capture failure gracefully
                                print("[UI] ❌ Capture3 failed - session may have been stopped")
                                // Don't navigate if capture failed
                                return
                            }
                            
                            print("[Flow] All three images captured. Stopping camera before navigation…")
                            
                            // ✅ CRITICAL FIX - Stop camera BEFORE navigating to ensure camera dot disappears
                            // Rule: General Coding - Explicit cleanup before navigation prevents camera indicator persistence
                            camera.stop()
                            
                            // Navigate to loading screen immediately after camera stop is initiated
                            // Rule: General Coding - Separate loading UI from result UI for better UX
                            goToLoading = true
                            
                            // Rule: Push Notifications - Mark analysis as started
                            AnalysisNotificationManager.shared.isAnalyzing = true
                            
                            // Rule: State Management - Track when request started for timeout detection
                            requestStartedAt = Date()
                            
                            // Rule: State Management - Create and store AI request task for tracking
                            aiRequestTask = Task { @MainActor in
                                let client = GeminiClient()
                                
                                // Rule: General Coding - Build base prompt with optional user comment appended
                                var prompt = """
                                Analyze the three images showing different perspectives of the same meal.
                                
                                FIRST: Check if the images contain any food. If NO food is visible in any of the images, return:
                                {
                                  \"noContent\": true,
                                  \"components\": [],
                                  \"totalCarbGrams\": 0,
                                  \"confidence\": 0,
                                  \"mealSummary\": \"No food detected\"
                                }
                                
                                PARTS OF THE PROMPT HAVE BEEN REMOVED FOR THIS REPO
                                                  

                                Return ONLY valid JSON (no markdown fences, no extra commentary). Use this exact schema and key names:
                                {
                                  \"noContent\": boolean,                // true if no food detected, false otherwise
                                  \"components\": [
                                    {
                                      \"description\": string,
                                      \"estimatedWeightGrams\": number,   // grams
                                      \"carbPercentage\": number,         // percentage as whole number (e.g., 23)
                                      \"carbContentGrams\": number        // grams
                                    }
                                  ],
                                  \"totalCarbGrams\": number,            // sum of all components' carbContentGrams
                                  \"confidence\": integer,               // 1-9 (0 if noContent is true)
                                  \"mealSummary\": string                // one-line description 3-5 words
                                }

                                Rules:
                                - Only calculate net carbs for food that is explicitly visible in the images. If only part of a plate or meal is shown in the frame, only estimate the visible portion. Do NOT guess the rest
                                - For cooked foods (pasta, rice, beans, lentils, vegetables, etc.), use the weight and carb percentage of the food in its COOKED form, not raw
                                - Use grams for weights and net carbohydrate content. Prefer integers where reasonable.
                                - Express carbPercentage as a whole number (e.g., 23 for 23%).
                                - Ensure the JSON is syntactically valid and parseable by JSONDecoder.
                                - Do not include any text before or after the JSON.
                                - Assume the three images depict the same meal from different angles and use the reference item consistently across images.
                                - Use the weight of edible parts of food components and also name them that way e.g. Mango (edible part)
                                - Set noContent to true ONLY if no food is visible in the images
                                """
                                
                                // Rule: General Coding - Append user comment to prompt if provided
                                if let comment = storage.userComment, !comment.isEmpty {
                                    prompt += "\n\nIMPORTANT USER NOTE: \(comment)"
                                    print("[AI] Including user comment in prompt: \(comment)")
                                }

                                let imgs = [storage.image1, storage.image2, storage.image3].compactMap { $0 }
                                if imgs.count == 3 {
                                    do {
                                        let text = try await client.send(images: imgs, prompt: prompt)
                                        print("[Gemini] Response received, length: \(text.count)")
                                        
                                        // Rule: State Management - Mark that we received a response
                                        hasReceivedResponse = true
                                        resultText = text
                                        
                                        // Helper function for sanitizing JSON
                                        func sanitizeJSONText(_ text: String) -> String {
                                            var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
                                            // Remove markdown code fences if present
                                            if t.hasPrefix("```") {
                                                t = t.replacingOccurrences(of: "```json", with: "")
                                                t = t.replacingOccurrences(of: "```", with: "")
                                            }
                                            // Extract the first JSON object if extra text surrounds it
                                            if let firstBrace = t.firstIndex(of: "{"), let lastBrace = t.lastIndex(of: "}") {
                                                let range = firstBrace...lastBrace
                                                return String(t[range])
                                            }
                                            return t
                                        }
                                        
                                        // Rule: General Coding - Check if AI detected no content BEFORE incrementing usage
                                        // Parse the response to check for noContent flag
                                        let sanitized = sanitizeJSONText(text)
                                        if let data = sanitized.data(using: .utf8),
                                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                                           let noContent = json["noContent"] as? Bool,
                                           noContent == true {
                                            print("[Gemini] ⚠️ AI detected no food in images, navigating to error view")
                                            // DO NOT increment usage count for no-content detections
                                            // DO NOT save to history for no-content detections
                                            
                                            // Rule: Push Notifications - Send notification for no-content error
                                            await MainActor.run {
                                                AnalysisNotificationManager.shared.notifyNoContent(
                                                    errorMessage: "There is no meal visible"
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
                                            print("[Capture3] Capture count incremented after successful AI response")
                                        }
                                        
                                        // First show success state in LoadingView (green circle)
                                        print("[Flow] AI response complete. Setting success state...")
                                        aiCompleted = true
                                        
                                        // Rule: Push Notifications - Mark analysis as complete
                                        AnalysisNotificationManager.shared.isAnalyzing = false
                                        
                                        // Wait for success animation to complete (0.3s delay as requested)
                                        // Rule: General Coding - Visual feedback before navigation
                                        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                                        print("[Flow] Success animation complete, navigating to result screen")
                                        goToResult = true

                                        // Build a short estimate string from the JSON for history (robust parsing)
                                        struct AIResult: Decodable {
                                            struct Component: Decodable {
                                                let description: String
                                                let estimatedWeightGrams: Double?
                                                let carbPercentage: Double?
                                                let carbContentGrams: Double?
                                            }
                                            let components: [Component]
                                            let totalCarbGrams: Double
                                            let confidence: Int
                                            let mealSummary: String
                                        }

                                        var estimateString = ""
                                        var totalCarbsForNotification: Int = 0
                                        var mealSummaryForNotification: String = ""
                                        
                                        if let text = resultText {
                                            let sanitized = sanitizeJSONText(text)
                                            if let data = sanitized.data(using: .utf8) {
                                                if let ai = try? JSONDecoder().decode(AIResult.self, from: data) {
                                                    let grams = Int(round(ai.totalCarbGrams))
                                                    totalCarbsForNotification = grams
                                                    mealSummaryForNotification = ai.mealSummary
                                                    if ai.mealSummary.isEmpty {
                                                        estimateString = "~\(grams)g carbs"
                                                    } else {
                                                        estimateString = "~\(grams)g carbs · \(ai.mealSummary)"
                                                    }
                                                } else {
                                                    // Fallback: try to extract values via regex if JSON decoding fails
                                                    let s = sanitized as NSString
                                                    var gramsPart: String?
                                                    var summaryPart: String?

                                                    if let gramsRegex = try? NSRegularExpression(pattern: "\"totalCarbGrams\"\\s*:\\s*([0-9]+(\\.[0-9]+)?)", options: []) {
                                                        if let match = gramsRegex.firstMatch(in: sanitized, options: [], range: NSRange(location: 0, length: s.length)) {
                                                            if let r = Range(match.range(at: 1), in: sanitized) {
                                                                let value = Double(sanitized[r]) ?? 0
                                                                gramsPart = String(Int(round(value)))
                                                            }
                                                        }
                                                    }

                                                    if let summaryRegex = try? NSRegularExpression(pattern: "\"mealSummary\"\\s*:\\s*\"([^\"]*)\"", options: []) {
                                                        if let match = summaryRegex.firstMatch(in: sanitized, options: [], range: NSRange(location: 0, length: s.length)) {
                                                            if let r = Range(match.range(at: 1), in: sanitized) {
                                                                summaryPart = String(sanitized[r])
                                                            }
                                                        }
                                                    }

                                                    if let grams = gramsPart, let summary = summaryPart, !summary.isEmpty {
                                                        estimateString = "~\(grams)g carbs · \(summary)"
                                                    } else if let grams = gramsPart {
                                                        estimateString = "~\(grams)g carbs"
                                                    }
                                                }
                                            }
                                        }

                                        // Fallback if parsing failed
                                        if estimateString.isEmpty {
                                            estimateString = "Unavailable"
                                        }

                                        // Persist the first image, estimate, and sanitized AI JSON to history (most recent first)
                                        if let first = storage.image1 {
                                            let jsonForHistory = sanitizeJSONText(resultText ?? "")
                                            await MainActor.run {
                                                historyStore.addEntry(firstImage: first, carbEstimate: estimateString, aiResultJSON: jsonForHistory)
                                            }
                                        }
                                        
                                        // Rule: Push Notifications - Send notification if app is in background
                                        if totalCarbsForNotification > 0 {
                                            await MainActor.run {
                                                AnalysisNotificationManager.shared.notifyAnalysisComplete(
                                                    totalCarbs: totalCarbsForNotification,
                                                    mealSummary: mealSummaryForNotification
                                                )
                                            }
                                        }
                                    } catch {
                                        print("[Gemini] Error: \(error)")
                                        
                                        // Rule: State Management - Mark that we received a response (even if error)
                                        hasReceivedResponse = true
                                        
                                        // Rule: Error Handling - Check if error is due to backgrounding/network interruption
                                        // URLError codes for network interruption: cancelled, networkConnectionLost, notConnectedToInternet
                                        let nsError = error as NSError
                                        let isNetworkInterruption = (nsError.domain == NSURLErrorDomain && 
                                                                     (nsError.code == NSURLErrorCancelled || 
                                                                      nsError.code == NSURLErrorNetworkConnectionLost ||
                                                                      nsError.code == NSURLErrorNotConnectedToInternet))
                                        
                                        if isNetworkInterruption {
                                            // Rule: Error Handling - Don't show error for network interruptions during backgrounding
                                            // Keep the loading state active - user should see "try again" or can dismiss
                                            print("[Capture3] ⚠️ Network interruption detected (likely due to backgrounding). Staying on loading screen.")
                                            await MainActor.run {
                                                // Don't set aiCompleted or navigate to error
                                                // LoadingView will continue showing, user can dismiss via navigation if needed
                                            }
                                        } else {
                                            // Rule: Error Handling - Show AI overload error for actual API errors
                                            print("[Capture3] ❌ Parsing/AI error - navigating to overload error view")
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
                                    print("[Gemini] Missing images. Got \(imgs.count)/3")
                                    
                                    // Rule: State Management - Mark that we received a response
                                    hasReceivedResponse = true
                                    resultText = "{\"components\":[],\"totalCarbGrams\":0,\"confidence\":1,\"mealSummary\":\"Missing images\"}"
                                    
                                    // Still show success animation and navigate for missing images case
                                    print("[Flow] Images missing. Setting success state...")
                                    aiCompleted = true
                                    
                                    try? await Task.sleep(nanoseconds: 300_000_000)
                                    print("[Flow] Success animation complete, navigating to result screen")
                                    goToResult = true
                                }
                            }
                        }
                    }
                }
            } else if auth == .denied || auth == .restricted {
                permissionDeniedView
            } else {
                ProgressView("Preparing camera…")
            }
        }
        .navigationDestination(isPresented: $goToLoading) {
            // Rule: SwiftUI-specific Patterns - Navigate to loading screen first
            LoadingView(aiCompleted: $aiCompleted, scanType: .meal)
            .navigationDestination(isPresented: $goToResult) {
                // Once AI completes, navigate from loading to result
                // Rule: State Management - Nested navigation for loading -> result flow
                ResultView(resultText: $resultText, isLoading: $isLoading, onDone: {
                    print("[Flow] ResultView Done button tapped -> triggering full flow dismissal.")
                    onCancel() // This will call ContentView's cancelCaptureFlow
                })
            }
            .navigationDestination(isPresented: $goToError) {
                // Rule: General Coding - Show error view when no content detected
                NoContentErrorView(errorType: .noFoodInImages, onDismiss: {
                    print("[Flow] NoContentErrorView dismissed -> triggering full flow dismissal.")
                    onCancel() // This will call ContentView's cancelCaptureFlow
                })
            }
            .navigationDestination(isPresented: $goToOverloadError) {
                // Rule: General Coding - Show overload error view for 503 errors
                AIOverloadErrorView(onDismiss: {
                    print("[Flow] AIOverloadErrorView dismissed -> triggering full flow dismissal.")
                    onCancel()
                })
            }
        }
        .sheet(isPresented: $showingHowTo) {
            HowToCaptureSheet()
                .presentationDetents([.large])
                .interactiveDismissDisabled(true)
        }
        .sheet(isPresented: $showingCommentSheet) {
            // Rule: SwiftUI-specific Patterns - Use @Binding for two-way data flow
            CommentInputSheet(comment: $userComment)
        }
        .onAppear {
            // Rule: State Management - Load existing comment from storage if available
            if let existingComment = storage.userComment {
                userComment = existingComment
            }
            
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
            print("[Lifecycle] Capture3View disappeared, stopping camera...")
            camera.stop()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Rule: SwiftUI Lifecycle - Monitor scene phase to handle app backgrounding gracefully
            print("[Capture3] Scene phase changed: \(oldPhase) -> \(newPhase)")
            
            if newPhase == .background {
                print("[Capture3] 🌙 App entered background")
                
                // Rule: State Management - Track when we backgrounded
                if goToLoading && !hasReceivedResponse {
                    backgroundedAt = Date()
                    wasBackgrounded = true
                    print("[Capture3] ⚠️ Loading screen backgrounded - request may be suspended by iOS")
                    print("[Capture3] Request started \(requestStartedAt.map { Date().timeIntervalSince($0) } ?? 0)s ago")
                }
            }
            
            if newPhase == .active {
                print("[Capture3] ☀️ App is now active")
                print("[Capture3] State - goToLoading: \(goToLoading), goToResult: \(goToResult), aiCompleted: \(aiCompleted), hasReceivedResponse: \(hasReceivedResponse), wasBackgrounded: \(wasBackgrounded)")
                
                if oldPhase == .background {
                    print("[Capture3] 🔄 App returned from background")
                    
                    // CRITICAL: If we were loading and backgrounded, we need to check the state immediately
                    if goToLoading && wasBackgrounded && !hasReceivedResponse {
                        let timeSinceBackground = backgroundedAt.map { Date().timeIntervalSince($0) } ?? 0
                        let timeSinceRequestStart = requestStartedAt.map { Date().timeIntervalSince($0) } ?? 0
                        
                        print("[Capture3] ⏱️ Time since background: \(String(format: "%.1f", timeSinceBackground))s")
                        print("[Capture3] ⏱️ Time since request start: \(String(format: "%.1f", timeSinceRequestStart))s")
                        
                        // Rule: Error Handling - iOS suspends network tasks after backgrounding
                        // Without a debugger attached, URLSession requests are often suspended
                        // and won't complete. We need to detect this and fail gracefully.
                        //
                        // AGGRESSIVE TIMEOUT: If backgrounded for >2 seconds without response,
                        // assume the request is stuck and won't complete.
                        if timeSinceBackground > 2.0 {
                            print("[Capture3] ❌ Request suspended by iOS backgrounding (>2s) - cancelling and going back")
                            
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
                            print("[Capture3] Going back to home screen")
                            DispatchQueue.main.async {
                                // Call onCancel to dismiss the entire flow
                                onCancel()
                            }
                            return
                        } else {
                            print("[Capture3] ℹ️ Brief background (<2s), waiting for response...")
                        }
                    }
                    
                    // Rule: State Management - Check if we already have a result
                    // If aiCompleted is true, the AI finished while backgrounded - show results
                    if aiCompleted && resultText != nil && goToLoading && !goToResult && !goToError && !goToOverloadError {
                        print("[Capture3] ✅ AI completed while backgrounded, triggering navigation to result")
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
        // Rule: General Coding - Show minimal Apple-style loading indicator during capture
        .overlay {
            if isCapturing {
                ZStack {
                    // Semi-transparent background
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    // Classic Apple loading indicator
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.5)
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
            .accessibilityLabel("Capture photo")
            .accessibilityIdentifier("capture-button")
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Text("Camera Access Needed").font(.headline)
            Text("Please allow camera access in Settings to capture meal photos.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }.buttonStyle(.borderedProminent)
        }.padding()
    }
}

#Preview {
    // Use static image preview since camera hardware isn't available in Xcode previews
    // Wrap in NavigationStack to simulate the actual navigation context
    NavigationStack {
        CaptureScaffold(
            title: "Side (near 0°)",
            step: 1,
            preview: AnyView(StaticCameraPreview()),
            onCancel: { print("Preview cancel tapped") },
            onInfo: { print("Preview info tapped") },
            onAddNote: { print("Preview add note tapped") },
            hasNote: false
        ) {
            // Preview capture button
            Button(action: { print("Preview capture tapped") }) {
                ZStack {
                    Circle().fill(Color.white).frame(width: 70, height: 70)
                    Circle().stroke(Color.gray.opacity(0.4), lineWidth: 3).frame(width: 64, height: 64)
                }
                .shadow(radius: 2)
                .accessibilityLabel("Capture photo")
                .accessibilityIdentifier("capture-button")
            }
        }
        .statusBarHidden(true)
        .navigationBarBackButtonHidden(true)
    }
    // Preview on an actual device size to get proper safe area insets
    .previewDevice(PreviewDevice(rawValue: "iPhone 15 Pro"))
    .previewDisplayName("iPhone 15 Pro")
}

