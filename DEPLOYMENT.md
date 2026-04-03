# Bottles Up Vendor - Deployment Guide

This guide will help you deploy the Bottles Up Vendor app to production.

## Prerequisites

- Flutter SDK (3.7.2 or later)
- Firebase CLI installed and authenticated
- Android Studio / Xcode (for mobile deployment)
- Firebase project set up with the following services:
  - Authentication
  - Firestore Database
  - Storage (optional, for profile images)

## Project Setup

### 1. Clone & Install Dependencies

```bash
git clone <your-repo-url>
cd bottles_up_vendor
flutter pub get
```

### 2. Firebase Configuration

#### Option A: Use Existing Configuration (bottles-up-2d907)
The app is already configured to connect to the existing `bottles-up-2d907` Firebase project.

#### Option B: Set Up New Firebase Project

1. Create a new Firebase project at [console.firebase.google.com](https://console.firebase.google.com)

2. Enable Authentication:
   - Go to Authentication > Sign-in method
   - Enable Email/Password provider

3. Set up Firestore Database:
   - Create a Firestore database
   - Set up the following collections:
     - `vendors` (for vendor user profiles)
     - `events` (for event data)
     - `bookings` (for customer bookings)
     - `inventory` (for bottle inventory)

4. Configure your apps:
   ```bash
   firebase login
   firebase init
   flutterfire configure
   ```

5. Update the generated `firebase_options.dart` file

### 3. Firestore Security Rules

Set up security rules in Firestore:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow vendors to read/write their own profile
    match /vendors/{vendorId} {
      allow read, write: if request.auth != null && request.auth.uid == vendorId;
    }
    
    // Allow authenticated vendors to read events, bookings, inventory
    match /events/{eventId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null; // Add role-based restrictions as needed
    }
    
    match /bookings/{bookingId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null; // Add role-based restrictions as needed
    }
    
    match /inventory/{itemId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null; // Add role-based restrictions as needed
    }
  }
}
```

## Build & Deploy

### Android Deployment

1. **Prepare for release:**
   ```bash
   flutter build appbundle
   ```

2. **Key configuration:**
   - Create a keystore for signing
   - Update `android/app/build.gradle` with signing config
   - Update `android/gradle.properties` with keystore details

3. **Upload to Google Play Store:**
   - Create a developer account
   - Upload the `.aab` file from `build/app/outputs/bundle/release/`

### iOS Deployment

1. **Prepare for release:**
   ```bash
   flutter build ios --release
   ```

2. **Xcode configuration:**
   - Open `ios/Runner.xcworkspace` in Xcode
   - Configure signing & capabilities
   - Set up push notifications (if needed)

3. **Upload to App Store:**
   - Archive the app in Xcode
   - Upload via Xcode Organizer or Application Loader

### Web Deployment

1. **Build for web:**
   ```bash
   flutter build web
   ```

2. **Deploy options:**
   - **Firebase Hosting:**
     ```bash
     firebase deploy --only hosting
     ```
   - **Other hosting services:** Upload the `build/web` folder

## Environment Configuration

### Production Environment Variables

Create a `.env.production` file:

```env
FIREBASE_PROJECT_ID=your-production-project-id
FIREBASE_API_KEY=your-production-api-key
FIREBASE_AUTH_DOMAIN=your-project.firebaseapp.com
FIREBASE_STORAGE_BUCKET=your-project.appspot.com
```

### Development vs Production

The app automatically detects the environment and uses appropriate configurations.

## Features

### ✅ Completed Features

1. **Authentication System**
   - Email/password login and registration
   - Password reset functionality
   - User session management
   - Profile management with sign-out

2. **Dashboard**
   - Real-time analytics and metrics
   - Event statistics
   - Booking overview
   - Revenue tracking

3. **Event Management**
   - View all events with images and details
   - Event status and availability tracking
   - Booking count and revenue per event

4. **Inventory Management**
   - Bottle inventory with categories
   - Stock level indicators
   - Featured items management
   - Brand and pricing information

5. **Booking Management**
   - Customer booking details
   - Booking status tracking
   - Contact information management

6. **UI/UX**
   - Dark theme with orange accents
   - Material 3 design system
   - Smooth animations and transitions
   - Responsive layout

### 🔄 Planned Enhancements

1. **Advanced Features**
   - Push notifications
   - Offline mode support
   - Advanced analytics
   - Export functionality

2. **Admin Features**
   - User role management
   - Permission system
   - Vendor verification

## Troubleshooting

### Common Issues

1. **Firebase connection issues:**
   - Verify `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) are correctly placed
   - Check Firebase project configuration

2. **Build issues:**
   - Run `flutter clean` and `flutter pub get`
   - Verify Flutter SDK version compatibility

3. **Authentication issues:**
   - Check Firebase Authentication is enabled
   - Verify security rules allow vendor access

### Performance Optimization

1. **Code optimization:**
   - Use `flutter build --split-debug-info` for better performance
   - Implement lazy loading for large lists
   - Optimize image loading with caching

2. **Firestore optimization:**
   - Implement proper indexing
   - Use pagination for large datasets
   - Cache frequently accessed data

## Monitoring & Analytics

### Firebase Analytics

The app is ready for Firebase Analytics integration:

```dart
// Add to main.dart
import 'package:firebase_analytics/firebase_analytics.dart';

// Track user events
FirebaseAnalytics.instance.logEvent(
  name: 'vendor_login',
  parameters: {'vendor_id': vendorId},
);
```

### Crashlytics

For crash reporting:

```bash
flutter pub add firebase_crashlytics
```

## Security Considerations

1. **Data Protection:**
   - All sensitive data is encrypted in transit
   - Firestore security rules restrict access
   - User authentication required for all operations

2. **API Security:**
   - Firebase security rules enforce access control
   - No hardcoded secrets in client code
   - Regular security audits recommended

## Support

For technical support or deployment issues:

1. Check the [Flutter documentation](https://docs.flutter.dev)
2. Review [Firebase documentation](https://firebase.google.com/docs)
3. Contact the development team

---

**Last Updated:** January 2025  
**App Version:** 1.0.0  
**Flutter Version:** 3.7.2+ 