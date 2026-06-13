# Xcode Environment Variables Setup - Complete Guide

## ✅ Setup Complete!

Your project now supports **both** approaches for loading environment variables:

1. **Xcode Native** - Click ▶️ in Xcode (uses generated xcconfig)
2. **Flutter Native** - Use `flutter run --dart-define-from-file=env.json`

---

## What Was Configured

### Files Created

1. **`ios/Scripts/generate_dart_defines.sh`**
   - Bash script that reads `env.json`
   - Extracts SUPABASE_URL and SUPABASE_ANON_KEY
   - Base64 encodes them
   - Generates `ios/Flutter/DartDefines.xcconfig`

2. **`scripts/build_ios_testflight.sh`**
   - Automated TestFlight build script
   - Generates env config → builds → ready for upload

### Files Modified

1. **`ios/Flutter/Debug.xcconfig`**
   - Added: `#include? "DartDefines.xcconfig"`

2. **`ios/Flutter/Release.xcconfig`**
   - Added: `#include? "DartDefines.xcconfig"`

3. **`.gitignore`**
   - Added: `ios/Flutter/DartDefines.xcconfig`
   - Prevents committing secrets

### Files Generated (Don't Commit!)

- **`ios/Flutter/DartDefines.xcconfig`** - Contains base64-encoded secrets

---

## How to Use

### Option 1: Xcode Play Button (New!)

```bash
# 1. Generate environment config (run once, or after env.json changes)
cd ios && SRCROOT="$(pwd)" bash Scripts/generate_dart_defines.sh && cd ..

# 2. Open Xcode
open ios/Runner.xcworkspace

# 3. Press ⌘R to run
```

Now clicking ▶️ in Xcode will include your environment variables!

### Option 2: VS Code (Still Works)

Just press **F5** - no changes needed.

### Option 3: Terminal (Still Works)

```bash
flutter run --dart-define-from-file=env.json
```

### Option 4: TestFlight Build (Automated)

```bash
./scripts/build_ios_testflight.sh
```

This:
1. Generates DartDefines.xcconfig
2. Runs flutter build ipa
3. Ready for Xcode Organizer upload

---

## Important: When to Regenerate Config

You must regenerate `DartDefines.xcconfig` whenever you:

- ✏️ Change values in `env.json`
- 📝 Add new environment variables
- 🔄 Switch environments (staging/production)

**Regenerate command:**
```bash
cd ios && SRCROOT="$(pwd)" bash Scripts/generate_dart_defines.sh && cd ..
```

---

## Adding New Environment Variables

### Step 1: Add to env.json

```json
{
  "SUPABASE_URL": "...",
  "SUPABASE_ANON_KEY": "...",
  "NEW_API_KEY": "new-value"  // ← Add this
}
```

### Step 2: Update the Generator Script

Edit `ios/Scripts/generate_dart_defines.sh`:

```bash
# Extract new variable
NEW_API_KEY=$(grep -o '"NEW_API_KEY"[[:space:]]*:[[:space:]]*"[^"]*"' "$ENV_FILE" | sed 's/.*"\([^"]*\)".*/\1/')

# Base64 encode
NEW_API_KEY_B64=$(echo -n "NEW_API_KEY=$NEW_API_KEY" | base64)

# Add to DART_DEFINES (update the cat command)
DART_DEFINES=$SUPABASE_URL_B64,$SUPABASE_ANON_KEY_B64,$NEW_API_KEY_B64
```

### Step 3: Use in Your App

```dart
const newApiKey = String.fromEnvironment('NEW_API_KEY');
```

### Step 4: Regenerate Config

```bash
cd ios && SRCROOT="$(pwd)" bash Scripts/generate_dart_defines.sh && cd ..
```

---

## Troubleshooting

### White Screen After Xcode Run

**Cause:** DartDefines.xcconfig not generated or outdated

**Fix:**
```bash
cd ios && SRCROOT="$(pwd)" bash Scripts/generate_dart_defines.sh && cd ..
```

Then clean build in Xcode (`⌘⇧K`).

### "env.json not found" Error

**Fix:** Create env.json from template:
```bash
cp env.example.json env.json
# Edit env.json with your actual credentials
```

### Changes to env.json Not Reflected

**Fix:** Regenerate the config:
```bash
cd ios && SRCROOT="$(pwd)" bash Scripts/generate_dart_defines.sh && cd ..
```

### TestFlight Build Has White Screen

**Cause:** Didn't regenerate config before building

**Fix:** Use the build script (it does this automatically):
```bash
./scripts/build_ios_testflight.sh
```

Or manually:
```bash
cd ios && SRCROOT="$(pwd)" bash Scripts/generate_dart_defines.sh && cd ..
flutter build ipa --release
```

### Script Permission Denied

**Fix:**
```bash
chmod +x ios/Scripts/generate_dart_defines.sh
chmod +x scripts/build_ios_testflight.sh
```

---

## Security Checklist

### ✅ Safe to Commit
- `env.example.json` (template)
- `ios/Scripts/generate_dart_defines.sh` (generator)
- `scripts/build_ios_testflight.sh` (build script)
- `ios/Flutter/Debug.xcconfig` (includes, not secrets)
- `ios/Flutter/Release.xcconfig` (includes, not secrets)

### ❌ NEVER Commit
- `env.json` (your credentials)
- `ios/Flutter/DartDefines.xcconfig` (generated, contains secrets)

### Verify .gitignore

```bash
# Should show:
# env.json
# ios/Flutter/DartDefines.xcconfig
grep -E "env.json|DartDefines.xcconfig" .gitignore
```

---

## Quick Reference

| Task | Command |
|------|---------|
| **Generate env config** | `cd ios && SRCROOT="$(pwd)" bash Scripts/generate_dart_defines.sh && cd ..` |
| **Run in Xcode** | Generate config → Open Xcode → ⌘R |
| **Run in VS Code** | Press F5 |
| **Run in Terminal** | `flutter run --dart-define-from-file=env.json` |
| **Build for TestFlight** | `./scripts/build_ios_testflight.sh` |
| **Add new env var** | Edit env.json → Update script → Regenerate config |

---

## Comparison: Xcode vs Flutter Native

| Feature | Xcode (New) | Flutter Native (Original) |
|---------|-------------|---------------------------|
| **Xcode ▶️ button** | ✅ Works | ❌ Doesn't work |
| **VS Code F5** | ✅ Works | ✅ Works |
| **Terminal** | ✅ Works | ✅ Works |
| **TestFlight** | ⚠️ Must run script first | ✅ One command |
| **Maintenance** | ⚠️ Update script for new vars | ✅ Zero maintenance |
| **Cross-platform** | ❌ iOS only | ✅ iOS + Android + Web |

**You now have both!** Use whichever fits your workflow.

---

## Next Steps

1. **Try Xcode Play Button:**
   ```bash
   cd ios && SRCROOT="$(pwd)" bash Scripts/generate_dart_defines.sh && cd ..
   open ios/Runner.xcworkspace
   # Press ⌘R
   ```

2. **Test TestFlight Build:**
   ```bash
   ./scripts/build_ios_testflight.sh
   ```

3. **See Comparison:**
   - Read `ENVIRONMENT_VARIABLES_COMPARISON.md` for detailed pros/cons

---

**Setup Complete!** 🎉

Your app now supports clicking ▶️ in Xcode while maintaining Flutter's native approach as a fallback.
