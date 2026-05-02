# App Display Name Change

## Changes Made

The app display name has been changed from "Bottles Up Vendor" / "bottles_up_vendor" to **"Vendor"** on both platforms.

---

## Files Modified

### Android
**File:** `android/app/src/main/AndroidManifest.xml`

**Change:**
```xml
<!-- Before -->
<application
    android:label="bottles_up_vendor"
    ...

<!-- After -->
<application
    android:label="Vendor"
    ...
```

This changes the app name that appears:
- On the Android home screen
- In the app drawer
- In recent apps list
- In Settings → Apps

---

### iOS
**File:** `ios/Runner/Info.plist`

**Changes:**
```xml
<!-- Before -->
<key>CFBundleDisplayName</key>
<string>Bottles Up Vendor</string>
...
<key>CFBundleName</key>
<string>bottles_up_vendor</string>

<!-- After -->
<key>CFBundleDisplayName</key>
<string>Vendor</string>
...
<key>CFBundleName</key>
<string>Vendor</string>
```

This changes the app name that appears:
- On the iOS home screen
- In the App Library
- In multitasking view
- In Settings → Apps
- In App Store listing

---

## How to Apply Changes

### For Development/Testing

**Android:**
```bash
# Clean and rebuild
flutter clean
flutter build apk

# Or run directly
flutter run
```

**iOS:**
```bash
# Clean and rebuild
flutter clean
flutter build ios

# Or run directly
flutter run
```

The new name "Vendor" will appear on your device after installing the app.

### For Production Release

**Android (Google Play):**
1. Build release APK/AAB:
   ```bash
   flutter build appbundle --release
   ```
2. The app will show as "Vendor" on users' devices
3. Note: The Google Play Store listing title is managed separately in the Play Console

**iOS (App Store):**
1. Build release IPA:
   ```bash
   flutter build ios --release
   ```
2. The app will show as "Vendor" on users' devices
3. Note: The App Store listing name is managed separately in App Store Connect

---

## Verification

After building and installing, verify the name change:

**Android:**
- Check app drawer - should show "Vendor"
- Check Settings → Apps - should show "Vendor"
- Check notification bar - should show "Vendor"

**iOS:**
- Check home screen - should show "Vendor" below icon
- Check Settings → General → iPhone Storage - should show "Vendor"
- Check App Library - should show "Vendor"

---

## Notes

1. **Package/Bundle ID unchanged**: The internal package name (`com.example.bottles_up_vendor` or similar) remains the same
2. **Source code unchanged**: Variable names and project structure remain as `bottles_up_vendor`
3. **User-facing only**: This change only affects what users see on their device
4. **Store listings**: App Store and Play Store listing names are managed separately in their respective consoles

---

## Rollback (If Needed)

To revert to the original name:

**Android** (`AndroidManifest.xml`):
```xml
android:label="bottles_up_vendor"
```

**iOS** (`Info.plist`):
```xml
<key>CFBundleDisplayName</key>
<string>Bottles Up Vendor</string>
...
<key>CFBundleName</key>
<string>bottles_up_vendor</string>
```

Then rebuild the app.

---

## Status

✅ **COMPLETE** - App display name changed to "Vendor" for both Android and iOS
