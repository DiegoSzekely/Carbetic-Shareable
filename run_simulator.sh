#!/bin/bash
set -e

DEVICE_NAME="iPhone 17 Pro"
SCHEME="CarbFinder"
BUNDLE_ID="com.diegoszekely.CarbFinder"

echo "📱 Booting $DEVICE_NAME..."
xcrun simctl boot "$DEVICE_NAME" || true

echo "🛠️  Building $SCHEME..."
xcodebuild -scheme "$SCHEME" -destination "platform=iOS Simulator,name=$DEVICE_NAME" -derivedDataPath build clean build | xcbeautify || xcodebuild -scheme "$SCHEME" -destination "platform=iOS Simulator,name=$DEVICE_NAME" -derivedDataPath build clean build

echo "📦 Installing app..."
xcrun simctl install "$DEVICE_NAME" build/Build/Products/Debug-iphonesimulator/$SCHEME.app

echo "🚀 Launching app..."
xcrun simctl launch "$DEVICE_NAME" "$BUNDLE_ID"

echo "✅ Done! Check the simulator window."
