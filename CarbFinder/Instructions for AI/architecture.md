# CarbFinder Architecture (Capture Flow)

This document explains the current camera capture flow so an AI (or developer) can safely understand and modify it.

## Overview
- We implement a simple 3-step photo capture flow using SwiftUI + AVFoundation.
- The three screens are: `Capture1View` (Scan from above), `Capture2View` (Scan 45 degree), `Capture3View` (Scan 90 degree).
- A shared in-memory holder `CaptureStorage` carries the three images between steps.
- A small coordinator `CaptureSessionCoordinator` manages the AVFoundation camera session, preview layer, and still photo capture.
- A reusable layout `CaptureScaffold` avoids duplicating UI across the three capture screens.

## Files and roles
- `ContentView.swift`
  - Entry point for the flow. Tapping the text navigates to `Capture1View`.
  - Owns a single `CaptureStorage` instance and passes it into the flow.
- `CaptureFlow.swift`
  - `CaptureSessionCoordinator`: sets up `AVCaptureSession`, starts/stops it, and captures photos via `AVCapturePhotoOutput`.
  - `CameraPreview`: a `UIViewControllerRepresentable` that hosts an `AVCaptureVideoPreviewLayer` for live camera.
  - `CaptureStorage`: simple class with three optional images: `image1`, `image2`, `image3`.
  - `CaptureScaffold`: a lightweight SwiftUI view that renders the common layout (top: preview with instruction; bottom: white area with capture button).
  - `Capture1View`, `Capture2View`, `Capture3View`: thin SwiftUI views that:
    - Request camera permission on appear; start/stop the session accordingly.
    - Render the scaffold with the appropriate instruction string.
    - On capture, store the image into `CaptureStorage` and advance to the next step (the 3rd logs readiness for AI).

## Data Flow
- `ContentView` creates `let storage = CaptureStorage()`.
- `Capture1View(storage:)` stores into `storage.image1`.
- `Capture2View(storage:)` stores into `storage.image2`.
- `Capture3View(storage:)` stores into `storage.image3`.
- After all three are set, the app can pass these images to the AI pipeline (to be wired next to `ResultView`).

## Navigation
- `ContentView` owns the top-level `NavigationStack`.
- `Capture1View` and `Capture2View` use `.navigationDestination(isPresented:)` to push the next view.
- We intentionally avoid nested `NavigationStack`s to keep navigation reliable and simple.

## Camera Handling (AVFoundation)
- `CaptureSessionCoordinator` encapsulates camera setup:
  - Configures back wide-angle camera input and a single `AVCapturePhotoOutput`.
  - Exposes `start()` and `stop()` to control the session lifecycle.
  - Provides `makePreviewLayer()` for the live preview.
  - Captures photos with `capture(completion:)`, returning a `UIImage?`.
- Delegate retention: `activePhotoDelegates` keeps the `AVCapturePhotoCaptureDelegate` alive until the callback fires. This prevents shutter sound without callback issues.
- Main thread: The capture completion is dispatched to the main queue to safely update SwiftUI state.

## Permission Handling
- `checkAndRequestCameraPermission` is called in `onAppear` of each capture view.
- If authorized, the view calls `camera.start()`; `camera.stop()` is called in `onDisappear`.
- If denied/restricted, a friendly UI is displayed with a button to open Settings.

## UI Layout
- `CaptureScaffold` uses a `GeometryReader` to allocate roughly 2/3 height to the preview (ignores top safe area) and 1/3 to the white control area with the circular capture button.
- Each screen shows a different instruction label in the top-left over the preview.
- A light haptic (`UIImpactFeedbackGenerator(style: .light).impactOccurred()`) fires on capture tap to improve perceived responsiveness.

## How to extend to ResultView
- After `Capture3View` saves `storage.image3`, navigate to your `ResultView` (not wired yet). Suggested approach:
  - Add a navigation state flag in `Capture3View` (e.g., `@State private var goToResult = false`).
  - After saving `image3`, set `goToResult = true`.
  - Attach `.navigationDestination(isPresented: $goToResult) { ResultView(storage: storage) }`.
  - `ResultView` can then read `storage.image1/2/3` and perform the AI request.

## Editing guidelines for AI
- Keep the architecture simple. Prefer small, focused types.
- Do not introduce Combine/ObservableObject unless necessary. Pass reference types via initializers.
- Do not add nested `NavigationStack`s. Use the existing stack from `ContentView`.
- If modifying capture behavior, preserve delegate retention and main-thread completion.
- If changing layout across capture screens, update `CaptureScaffold` so all screens stay consistent.
- Add debug logs (`print("[Tag] …")`) and comments for traceability.

## Debug logging
- Permission flow logs under `[Permissions]`.
- Camera lifecycle and capture logs under `[Camera]`.
- UI interactions and navigation under `[UI]` / `[Flow]` / `[Lifecycle]`.

