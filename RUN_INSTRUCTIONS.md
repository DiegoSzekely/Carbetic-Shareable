# How to Run CarbFinder

Since "Antigravity" is a text-based environment, it cannot directly display the app's UI. However, you can easily run the app on your local machine using the Simulator or a real device.

## Option 1: Run on Simulator (Easiest)

I have created a script to automate this for you.

1.  **Run the helper script:**
    ```bash
    sh run_simulator.sh
    ```
    This will:
    - Boot the **iPhone 17 Pro** simulator.
    - Build the app.
    - Install and launch it automatically.

2.  **Manual Commands (if you prefer):**
    ```bash
    # Boot Simulator
    xcrun simctl boot "iPhone 17 Pro"

    # Build App
    xcodebuild -scheme CarbFinder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build

    # Install App
    xcrun simctl install "iPhone 17 Pro" build/Build/Products/Debug-iphonesimulator/CarbFinder.app

    # Launch App
    xcrun simctl launch "iPhone 17 Pro" com.diegoszekely.CarbFinder
    ```

## Option 2: Run on Real iPhone

Running on a real device requires code signing, which is best handled by Xcode directly.

1.  **Open the project in Xcode:**
    ```bash
    open CarbFinder.xcodeproj
    ```
2.  **Connect your iPhone** via USB.
3.  **Select your device** in the top toolbar (where it currently says a simulator name).
4.  **Press Cmd+R** to build and run.
5.  *Note: You may need to trust your developer certificate in Settings > General > VPN & Device Management on your iPhone.*

## Troubleshooting

-   **"Simulator already booted"**: This is fine, the script handles it.
-   **Build Fails**: Ensure you have the latest Xcode installed and have accepted the license (`sudo xcodebuild -license`).
