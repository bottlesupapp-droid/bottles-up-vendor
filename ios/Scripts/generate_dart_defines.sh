#!/bin/bash

# Generate DART_DEFINES for Xcode builds from env.json
# This script creates a temporary xcconfig file with environment variables

set -e

# Path to env.json (relative to ios folder)
ENV_FILE="${SRCROOT}/../env.json"
OUTPUT_FILE="${SRCROOT}/Flutter/DartDefines.xcconfig"

# Check if env.json exists
if [ ! -f "$ENV_FILE" ]; then
    echo "Warning: env.json not found at $ENV_FILE"
    echo "App may crash due to missing environment variables"
    echo "Creating empty DartDefines.xcconfig"
    echo "// No environment variables loaded" > "$OUTPUT_FILE"
    exit 0
fi

# Extract values from env.json
SUPABASE_URL=$(grep -o '"SUPABASE_URL"[[:space:]]*:[[:space:]]*"[^"]*"' "$ENV_FILE" | sed 's/.*"\([^"]*\)".*/\1/')
SUPABASE_ANON_KEY=$(grep -o '"SUPABASE_ANON_KEY"[[:space:]]*:[[:space:]]*"[^"]*"' "$ENV_FILE" | sed 's/.*"\([^"]*\)".*/\1/')

# Base64 encode (Flutter's expected format for DART_DEFINES)
SUPABASE_URL_B64=$(echo -n "SUPABASE_URL=$SUPABASE_URL" | base64)
SUPABASE_ANON_KEY_B64=$(echo -n "SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" | base64)

# Write to xcconfig file
cat > "$OUTPUT_FILE" << EOF
// Auto-generated from env.json - DO NOT EDIT MANUALLY
// Generated on $(date)

DART_DEFINES=$SUPABASE_URL_B64,$SUPABASE_ANON_KEY_B64
EOF

echo "Generated DartDefines.xcconfig with environment variables"
