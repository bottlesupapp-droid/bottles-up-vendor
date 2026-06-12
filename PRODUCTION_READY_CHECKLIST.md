# Production Readiness Checklist

## ✅ Completed Items

### Error Handling
- [x] Created centralized error handler (`lib/core/utils/error_handler.dart`)
- [x] Added global error boundary in `main.dart`
- [x] Sanitizes sensitive data before logging
- [x] User-friendly error messages for Auth/Database/Storage
- [x] TODO markers for Sentry/Crashlytics integration

### Build Configuration
- [x] Android minSdk set to 21
- [x] Android release signing configured (with example template)
- [x] ProGuard rules added for code protection
- [x] iOS configuration verified (HTTPS only, no ATS exceptions)
- [x] Multi-dex enabled for Firebase compatibility

### Code Quality
- [x] Flutter analyze: 0 errors
- [x] No sensitive data in print statements
- [x] Unused imports removed
- [x] Smoke tests created

## 🔴 Critical Before Production

### 1. Database Security (BLOCKER)
- [ ] Run `database/verify_rls.sql` in Supabase
- [ ] Fix ALL 🔴 CRITICAL issues in `database/SECURITY_ISSUES.md`
- [ ] Enable RLS on financial tables (stripe_accounts, payout_records)
- [ ] Fix venue_boosts policy (currently allows any authenticated user)
- [ ] Add policies for onboarding tables

### 2. Crash Reporting
- [ ] Choose service: Sentry or Firebase Crashlytics
- [ ] Replace TODO markers in `lib/main.dart:52-54`
- [ ] Replace TODO markers in `lib/core/utils/error_handler.dart:123,158`
- [ ] Test crash reporting works

### 3. Release Signing
- [ ] Generate Android keystore: `keytool -genkey -v -keystore android/upload-keystore.jks...`
- [ ] Copy `android/key.properties.example` to `android/key.properties`
- [ ] Fill in keystore credentials
- [ ] Test release build: `flutter build apk --release`

## ⚠️ Important Before Production

### Testing
- [ ] Test on real devices (Android & iOS)
- [ ] Test all onboarding flows
- [ ] Test Stripe Connect integration
- [ ] Test QR code scanning
- [ ] Test file uploads
- [ ] Test with slow/no network

### Security
- [ ] Review all Supabase RLS policies
- [ ] Verify no API keys in code
- [ ] Check `.gitignore` includes `key.properties`
- [ ] Audit third-party dependencies

### Performance
- [ ] Test with large datasets
- [ ] Profile memory usage
- [ ] Check for memory leaks
- [ ] Optimize image loading

## 📋 Nice to Have

- [ ] Add more comprehensive tests
- [ ] Set up CI/CD pipeline
- [ ] Add analytics (Google Analytics/Mixpanel)
- [ ] Performance monitoring (Firebase Performance)
- [ ] Feature flags system

## 🚀 Deployment Steps

1. Fix database security issues
2. Set up crash reporting
3. Generate release keystore
4. Build release: `flutter build apk --release` 
5. Test on physical devices
6. Deploy to internal testing
7. Beta testing phase
8. Production release

## 📞 Support

- Database issues: See `database/SECURITY_ISSUES.md`
- Error handling: See `PRODUCTION_HARDENING_SUMMARY.md`
- Build issues: See `CLAUDE.md`
