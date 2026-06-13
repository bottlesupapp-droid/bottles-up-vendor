#!/bin/bash

set -e

echo "🚀 Building iOS app for TestFlight..."
echo ""

# Check if env.json exists
if [ ! -f "env.json" ]; then
    echo "❌ Error: env.json not found!"
    echo "Please create env.json with your credentials."
    echo "Example: cp env.example.json env.json"
    exit 1
fi

# Generate DartDefines.xcconfig for Xcode
echo "📝 Generating environment config for Xcode..."
cd ios && SRCROOT="$(pwd)" bash Scripts/generate_dart_defines.sh && cd ..
echo ""

# Verify the config was generated
if [ ! -f "ios/Flutter/DartDefines.xcconfig" ]; then
    echo "❌ Error: DartDefines.xcconfig was not generated"
    exit 1
fi

echo "✅ Environment config generated successfully"
echo ""

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean
flutter pub get
echo ""

# Build iOS archive
echo "📦 Building iOS archive..."
flutter build ipa --release

echo ""
echo "✅ Build complete!"
echo "📍 Archive location: build/ios/archive/Runner.xcarchive"
echo ""
echo "📤 Next steps:"
echo "   1. Open Xcode"
echo "   2. Window → Organizer"
echo "   3. Select the archive"
echo "   4. Click 'Distribute App'"
echo "   5. Choose 'TestFlight & App Store'"
