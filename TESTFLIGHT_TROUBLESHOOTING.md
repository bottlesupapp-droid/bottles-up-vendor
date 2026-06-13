# TestFlight White Screen - Troubleshooting

## The Error You're Seeing

```
Unhandled Exception: Exception: SUPABASE_URL is not configured!
```

This means the app received by TestFlight doesn't have the environment variables embedded.

---

## Root Cause

Two possibilities:

### 1. TestFlight Is Still Running Old Build (Most Likely)

- ✅ You built with `--dart-define-from-file=env.json` ✓
- ✅ IPA file has variables embedded ✓
- ❌ TestFlight is running older version ✗

**Fix:**
```bash
# Delete app from device
# Wait 5-10 minutes for TestFlight to refresh
# Reinstall from TestFlight
# It should prompt for new build
```

### 2. Build Command Didn't Include The Flag

If you accidentally ran:
```bash
flutter build ipa --release  # ❌ Missing --dart-define-from-file=env.json
```

Instead of:
```bash
flutter build ipa --dart-define-from-file=env.json --release  # ✅ Correct
```

---

## Step-by-Step Fix

### Step 1: Delete the App from Device

1. On your iPhone/iPad
2. Press and hold the **Vendor** app
3. Select **Remove App**
4. Select **Delete App**
5. Confirm

### Step 2: Wait for TestFlight to Refresh

Wait 5-10 minutes for TestFlight's internal cache to update.

### Step 3: Reinstall from TestFlight

1. Open TestFlight app
2. Go to **Vendor**
3. Tap **Install** or **Update**
4. When prompted, choose the **latest build** (with today's date)
5. Install

### Step 4: Test

Launch the app. It should:
- ✅ Not show white screen
- ✅ Connect to Supabase immediately
- ✅ No "SUPABASE_URL is not configured" errors

---

## How to Verify Build Has Environment Variables

Before uploading next time, you can verify the build includes the env vars:

```bash
# 1. Build with the flag
flutter build ipa --dart-define-from-file=env.json --release

# 2. Extract the app binary
cd build/ios/ipa/
unzip -q Vendor.ipa
cd Payload/Runner.app/

# 3. Check if SUPABASE strings are in the binary
strings Runner | grep -i supabase | head -5
```

If you see Supabase-related strings, the variables are embedded.

---

## Why This Happened

When you build with `flutter build ipa --dart-define-from-file=env.json`:

1. Flutter reads env.json
2. Passes to Dart compiler as `--dart-define` flags
3. Dart compiler compiles them as **constants into the binary**
4. These constants are now **part of the app binary forever**
5. When uploaded to TestFlight, the binary has them

The variables are **embedded at compile time**, not loaded at runtime.

---

## If Still White Screen After Reinstalling

### Check 1: Verify env.json Has Values

```bash
cat env.json
# Should show:
# {
#   "SUPABASE_URL": "https://...",
#   "SUPABASE_ANON_KEY": "eyJ...",
# }
```

If empty or template values, update it.

### Check 2: Rebuild with Fresh env.json

```bash
flutter clean
flutter pub get
flutter build ipa --dart-define-from-file=env.json --release
```

### Check 3: Upload New Build to TestFlight

1. Use Transporter to upload new IPA
2. Wait for TestFlight to process (5-10 min)
3. Delete and reinstall app
4. Test again

### Check 4: Check TestFlight Build Version

In TestFlight:
1. Tap **Vendor**
2. Scroll down to **Build History**
3. See which build is **Latest External**
4. Note the **Build Number**

Compare with your local build:
```bash
grep version pubspec.yaml
# Should match TestFlight version
```

---

## Recommended Process for Future Builds

1. **Build with flag:**
   ```bash
   flutter build ipa --dart-define-from-file=env.json --release
   ```

2. **Upload to TestFlight:**
   ```bash
   open -a Transporter
   # Drag and drop: build/ios/ipa/Vendor.ipa
   ```

3. **Wait for processing:** 5-10 minutes

4. **Test on device:**
   - Delete old app
   - Wait 5 minutes
   - Install from TestFlight
   - Test

---

## Quick Checklist

- [ ] Delete app from device
- [ ] Wait 5-10 minutes
- [ ] Reinstall from TestFlight (latest build)
- [ ] Test app launches
- [ ] No white screen
- [ ] Supabase connects

---

## Still Having Issues?

### Scenario A: "I see multiple builds in TestFlight"

If TestFlight shows multiple builds:
- Tap the **latest one** with today's date
- It should say "New build available"
- Install that one

### Scenario B: "I don't see my new build"

- Wait another 5 minutes
- TestFlight processing can take 10-15 minutes after upload
- Check your email for upload confirmation

### Scenario C: "Build number hasn't changed"

- Same as old build
- It's definitely not the new one
- Check if upload actually succeeded in Transporter

---

## The Important Part

**The environment variables are built INTO the app at compile time.**

This means:
- ✅ Once embedded, they're permanent
- ✅ Don't need to be set elsewhere
- ✅ Work exactly the same in TestFlight, Play Store, or production
- ✅ No runtime configuration needed

When you built with `flutter build ipa --dart-define-from-file=env.json`, your Supabase URL and API key were compiled directly into the app binary.

If TestFlight build doesn't have them, the build command didn't include the flag.

---

## Status

**Current build:** Jun 14 01:07 (23MB)
- ✅ Built with `--dart-define-from-file=env.json`
- ✅ Environment variables embedded
- ✅ Ready for TestFlight

**Issue:** TestFlight running old cached version
**Solution:** Delete app, wait 5 min, reinstall from TestFlight

---

**Last Updated:** June 14, 2026
