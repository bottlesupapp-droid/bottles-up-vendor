# Environment Variables Setup - Production Ready

## The Approach: Flutter Native (`--dart-define-from-file`)

This is the **official Flutter method** that works everywhere:
- ✅ Development (VS Code, Xcode, Terminal)
- ✅ TestFlight builds
- ✅ Play Store builds
- ✅ CI/CD pipelines
- ✅ iOS, Android, Web

---

## Files You Need

### ✅ Already Created

1. **`env.json`** (git-ignored)
   - Your Supabase credentials
   - Never committed to version control

2. **`env.example.json`** (in version control)
   - Template for team members
   - Shows what variables are needed

3. **`.vscode/launch.json`** (in version control)
   - VS Code auto-loads `env.json` when you press F5
   - No manual flag needed

4. **`build-ios.sh`** (in version control)
   - One-command TestFlight build
   - Includes the `--dart-define-from-file` flag automatically

5. **`build-android.sh`** (in version control)
   - One-command Play Store build
   - Includes the `--dart-define-from-file` flag automatically

---

## How to Use

### Development

#### Option 1: VS Code (Easiest)
```bash
# Just press F5
# The .vscode/launch.json automatically includes --dart-define-from-file=env.json
```

#### Option 2: Terminal
```bash
flutter run --dart-define-from-file=env.json
```

#### Option 3: Xcode (Direct)
```bash
open ios/Runner.xcworkspace
# Then use Terminal to run with the flag above, or press F5 in VS Code
```

### Testing on Device
```bash
flutter run --dart-define-from-file=env.json -d <device-id>
```

---

## Building for Production

### iOS - TestFlight

**Easiest:**
```bash
./build-ios.sh
```

**Or manually:**
```bash
flutter build ipa --dart-define-from-file=env.json --release
```

Then:
1. Open `build/ios/archive/Runner.xcarchive` in Xcode Organizer
2. Click **Distribute App**
3. Choose **TestFlight**
4. Upload

### Android - Play Store

**Easiest:**
```bash
./build-android.sh
```

**Or manually:**
```bash
flutter build appbundle --dart-define-from-file=env.json --release
```

Then upload `build/app/outputs/bundle/release/app-release.aab` to Google Play Console.

---

## Adding New Environment Variables

### Step 1: Add to `env.json`

```json
{
  "SUPABASE_URL": "https://...",
  "SUPABASE_ANON_KEY": "eyJ...",
  "NEW_VAR": "new-value"  // ← Add this
}
```

### Step 2: Update `env.example.json`

```json
{
  "SUPABASE_URL": "https://your-project.supabase.co",
  "SUPABASE_ANON_KEY": "your-anon-key-here",
  "NEW_VAR": "new-value-template"  // ← Add this
}
```

### Step 3: Use in Code

```dart
const newVar = String.fromEnvironment('NEW_VAR');
```

---

## Security

### ✅ Safe to Commit
- `env.example.json` (template only)
- `.vscode/launch.json` (references env.json, not secrets)
- `build-ios.sh` and `build-android.sh` (build scripts)

### ❌ NEVER Commit
- `env.json` (contains your actual credentials)

### Verify .gitignore

```bash
grep "env.json" .gitignore
# Should output: env.json
```

---

## Troubleshooting

### White Screen After Build

**Cause:** Environment variables not loaded

**Fix:** Verify you built with the flag:
```bash
# Correct ✅
flutter build ipa --dart-define-from-file=env.json

# Wrong ❌
flutter build ipa  # Missing the flag
```

### "SUPABASE_URL is not configured"

**Cause:** Ran without `--dart-define-from-file`

**Fix:** Always include the flag or use:
- VS Code: Press F5 (auto-includes flag)
- Terminal: `flutter run --dart-define-from-file=env.json`
- Build script: `./build-ios.sh`

### env.json Not Found

**Fix:**
```bash
cp env.example.json env.json
# Edit env.json with your actual credentials
```

---

## Quick Reference

| Task | Command |
|------|---------|
| **Dev - VS Code** | Press F5 |
| **Dev - Terminal** | `flutter run --dart-define-from-file=env.json` |
| **Test on Device** | `flutter run --dart-define-from-file=env.json -d <device-id>` |
| **Build iOS Release** | `flutter build ipa --dart-define-from-file=env.json --release` |
| **Build Android Release** | `flutter build appbundle --dart-define-from-file=env.json --release` |
| **Quick iOS Build** | `./build-ios.sh` |
| **Quick Android Build** | `./build-android.sh` |

---

## Why This Approach

### ✅ Pros
1. **Official Flutter method** - Documented, supported, maintained
2. **Works everywhere** - Dev, TestFlight, Play Store, Web, Desktop
3. **Simple** - One flag, one command
4. **CI/CD friendly** - Same command in GitHub Actions, GitLab CI, etc.
5. **Zero maintenance** - No scripts to maintain
6. **Consistent** - Same across all platforms and team members
7. **Secure** - No generated files with secrets
8. **Future-proof** - Won't break with Flutter updates

### ❌ Cons
1. **Must remember the flag** - Mitigated by VS Code and build scripts
2. **Can't click Xcode play button** - But VS Code F5 is faster anyway

---

## CI/CD Example

### GitHub Actions

```yaml
- name: Create env.json from secrets
  run: |
    echo '{
      "SUPABASE_URL": "${{ secrets.SUPABASE_URL }}",
      "SUPABASE_ANON_KEY": "${{ secrets.SUPABASE_ANON_KEY }}"
    }' > env.json

- name: Build iOS for TestFlight
  run: flutter build ipa --dart-define-from-file=env.json --release

- name: Build Android for Play Store
  run: flutter build appbundle --dart-define-from-file=env.json --release
```

---

## Setup Checklist

- [x] `env.json` created with your credentials
- [x] `env.example.json` created as template
- [x] `.gitignore` excludes `env.json`
- [x] `.vscode/launch.json` configured
- [x] `build-ios.sh` created and executable
- [x] `build-android.sh` created and executable
- [x] `main.dart` loads environment variables with `String.fromEnvironment()`
- [x] Tested development build
- [x] Tested TestFlight build
- [x] Tested Play Store build

---

## Team Onboarding

New developers just need to:

```bash
# 1. Clone repo
git clone <repo>
cd vendor-app

# 2. Create env.json from template
cp env.example.json env.json

# 3. Edit with their own credentials (if needed) or use shared env
nano env.json

# 4. Run
flutter pub get
flutter run --dart-define-from-file=env.json
# Or: Press F5 in VS Code
```

---

## Production Deployment

### iOS - TestFlight

```bash
./build-ios.sh
# Then upload via Xcode Organizer
```

### Android - Play Store

```bash
./build-android.sh
# Then upload to Google Play Console
```

Both commands:
1. Include environment variables
2. Build in release mode
3. Create production-ready artifacts

---

**Status:** ✅ Production Ready
**Last Updated:** 2026-06-13
**Works On:** iOS, Android, Web, macOS, Windows, Linux
