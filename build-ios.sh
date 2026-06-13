#!/bin/bash

# Build script for iOS - automatically includes environment variables

echo "🚀 Building iOS app with environment variables..."

# Check if env.json exists
if [ ! -f "env.json" ]; then
    echo "❌ Error: env.json not found!"
    echo "Please create env.json based on env.example.json"
    exit 1
fi

# Build for TestFlight/App Store
flutter build ipa --dart-define-from-file=env.json

echo "✅ Build complete!"
echo ""
echo "Next steps:"
echo "1. Open Xcode: open ios/Runner.xcworkspace"
echo "2. Go to Window → Organizer"
echo "3. Select your archive and upload to TestFlight"
