#!/bin/bash

# Build script for Android - automatically includes environment variables

echo "🚀 Building Android app with environment variables..."

# Check if env.json exists
if [ ! -f "env.json" ]; then
    echo "❌ Error: env.json not found!"
    echo "Please create env.json based on env.example.json"
    exit 1
fi

# Check if key.properties exists (for release builds)
if [ ! -f "android/key.properties" ]; then
    echo "⚠️  Warning: android/key.properties not found!"
    echo "Release signing will not work. See android/key.properties.example"
    echo ""
fi

# Build APK for testing
echo "Building APK for testing..."
flutter build apk --dart-define-from-file=env.json

echo ""
echo "Building App Bundle for Play Store..."
flutter build appbundle --dart-define-from-file=env.json

echo ""
echo "✅ Build complete!"
echo ""
echo "Output files:"
echo "  APK: build/app/outputs/flutter-apk/app-release.apk"
echo "  Bundle: build/app/outputs/bundle/release/app-release.aab"
