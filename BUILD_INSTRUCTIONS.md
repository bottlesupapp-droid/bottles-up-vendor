# Build Instructions - Environment Variables

## The Simple Truth

Flutter's `--dart-define-from-file` is the **only** supported way to load environment variables. There's no need for complex bash scripts or xcconfig files.

---

## For Development

### VS Code (Already Configured ✅)

Just press **F5**. The `.vscode/launch.json` file automatically includes the flag.

### Terminal

```bash
flutter run --dart-define-from-file=env.json
```

### Xcode (Don't Use Directly)

**Don't run from Xcode's play button** - it won't include environment variables.

Instead, use:
```bash
# Open with environment variables
flutter run --dart-define-from-file=env.json
```

Then attach Xcode debugger if needed: **Debug → Attach to Process → Runner**

---

## For TestFlight Builds

### Using the Build Script (Recommended)

```bash
./build-ios.sh
```

This runs:
```bash
flutter build ipa --dart-define-from-file=env.json
```

Then upload via Xcode Organizer.

### Manual Build

```bash
# Build
flutter build ipa --dart-define-from-file=env.json

# Upload
open build/ios/archive/Runner.xcarchive
# Xcode Organizer opens → Distribute App
```

---

## For Play Store Builds

### Using the Build Script

```bash
./build-android.sh
```

### Manual Build

```bash
flutter build appbundle --dart-define-from-file=env.json
```

Upload `build/app/outputs/bundle/release/app-release.aab` to Play Console.

---

## Why This Is The Right Way

### ✅ Flutter's Official Method
- Uses `--dart-define-from-file` (supported since Flutter 3.7)
- Works identically across iOS, Android, Web, Desktop
- No platform-specific hacks needed

### ✅ Consistent Everywhere
- Development: Same command
- CI/CD: Same command
- Release builds: Same command

### ✅ Secure
- `env.json` is git-ignored
- No secrets in version control
- No generated files to worry about

---

## File Structure

```
your-app/
├── env.json                    # Your credentials (git-ignored)
├── env.example.json            # Template for team
├── .vscode/
│   └── launch.json             # VS Code config (already created)
├── build-ios.sh                # iOS build script (already created)
└── build-android.sh            # Android build script (already created)
```

---

## Common Questions

### Q: Can I run from Xcode's play button?

**A:** No, Xcode doesn't know about `--dart-define-from-file`. Use `flutter run --dart-define-from-file=env.json` or VS Code (F5).

### Q: Will TestFlight builds work?

**A:** Yes! As long as you build with:
```bash
flutter build ipa --dart-define-from-file=env.json
```

The build scripts (`build-ios.sh`, `build-android.sh`) do this automatically.

### Q: What about CI/CD (GitHub Actions, etc.)?

**A:** Create `env.json` from secrets:

```yaml
# .github/workflows/build.yml
- name: Create env.json
  run: |
    echo '{
      "SUPABASE_URL": "${{ secrets.SUPABASE_URL }}",
      "SUPABASE_ANON_KEY": "${{ secrets.SUPABASE_ANON_KEY }}"
    }' > env.json

- name: Build iOS
  run: flutter build ipa --dart-define-from-file=env.json
```

### Q: Can I use different env files for staging/prod?

**A:** Yes! Create multiple files:

```bash
env.staging.json
env.production.json
```

Then build with:
```bash
flutter build ipa --dart-define-from-file=env.production.json
```

---

## Troubleshooting

### White screen crash

**Check:** Is `env.json` missing?
```bash
cat env.json  # Should show your credentials
```

**Fix:** Create it from template:
```bash
cp env.example.json env.json
# Edit env.json with your values
```

### "SUPABASE_URL is not configured"

**Cause:** Ran without the flag

**Fix:** Always use:
```bash
flutter run --dart-define-from-file=env.json
# or
./build-ios.sh
# or press F5 in VS Code
```

### Changes to env.json not reflected

**Fix:** Clean and rebuild:
```bash
flutter clean
flutter pub get
flutter run --dart-define-from-file=env.json
```

---

## Summary

| Build Type | Command |
|------------|---------|
| Development (VS Code) | Press **F5** ✅ |
| Development (Terminal) | `flutter run --dart-define-from-file=env.json` |
| TestFlight | `./build-ios.sh` or `flutter build ipa --dart-define-from-file=env.json` |
| Play Store | `./build-android.sh` or `flutter build appbundle --dart-define-from-file=env.json` |

**Key Point:** Always include `--dart-define-from-file=env.json` in every build command (except when using VS Code or the build scripts, which do it automatically).

---

## Already Configured ✅

Your project already has:
- ✅ `.vscode/launch.json` - VS Code auto-includes flag
- ✅ `build-ios.sh` - TestFlight build script
- ✅ `build-android.sh` - Play Store build script
- ✅ `env.json` - Your credentials (git-ignored)

**You're ready to build!** Just use the scripts or VS Code. 🚀
