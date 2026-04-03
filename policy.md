# Privacy Policy

**Last Updated:** January 2025

## 1. Introduction
Bottles Up ("we," "our," or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our vendor platform.

By using our services, you consent to the data practices described in this policy.

## 2. Information We Collect

### 2.1. Account Information
When you register as a vendor, we collect:
• Full name and business name
• Email address and phone number
• Business address and location
• Tax identification information
• Banking and payment details
• Profile photos and business logos

### 2.2. Business Information
• Event listings and descriptions
• Inventory and product details
• Pricing and availability
• Operating hours and policies
• Business licenses and certifications

### 2.3. Transaction Data
• Booking details and history
• Payment transactions
• Refund and cancellation records
• Customer communication logs
• Financial reports and analytics

### 2.4. Technical Information
• IP address and device information
• Browser type and version
• Operating system
• Location data
• App usage patterns and analytics
• Crash reports and error logs

## 3. How We Use Your Information
We use collected information to:

### 3.1. Provide Services
• Create and manage your account
• Process bookings and payments
• Facilitate customer communication
• Generate analytics and reports
• Provide customer support

### 3.2. Improve Our Platform
• Enhance user experience
• Develop new features
• Conduct research and analysis
• Fix bugs and technical issues
• Optimize performance

### 3.3. Communication
• Send booking notifications
• Provide account updates
• Share promotional content (with consent)
• Send administrative messages
• Request feedback and reviews

### 3.4. Security and Compliance
• Detect and prevent fraud
• Enforce our Terms of Service
• Comply with legal obligations
• Resolve disputes
• Protect user safety

## 4. Information Sharing

### 4.1. With Customers
We share necessary information with customers for:
• Booking confirmations
• Event details and locations
• Contact information for coordination
• Business verification

### 4.2. With Service Providers
We may share data with:
• Payment processors (Stripe, PayPal)
• Cloud storage providers (AWS, Firebase)
• Analytics services (Google Analytics)
• Email service providers
• Customer support tools

### 4.3. For Legal Reasons
We may disclose information:
• To comply with legal obligations
• In response to court orders or subpoenas
• To protect our rights and property
• To prevent fraud or illegal activities
• In connection with business transfers

### 4.4. With Your Consent
We may share information for purposes you explicitly approve.

## 5. Data Security

### 5.1. Security Measures
We implement industry-standard security:
• Encryption of data in transit (TLS/SSL)
• Encryption of sensitive data at rest
• Secure authentication systems
• Regular security audits
• Access controls and monitoring
• Secure backup systems

### 5.2. Your Responsibility
You must:
• Keep login credentials confidential
• Use strong, unique passwords
• Enable two-factor authentication
• Report suspicious activity immediately
• Secure your devices and network

### 5.3. No Absolute Security
While we strive to protect your data, no system is completely secure. We cannot guarantee absolute security.

## 6. Your Rights and Choices

### 6.1. Access and Correction
You can:
• Access your personal information
• Update or correct inaccuracies
• Download your data
• Request data portability

### 6.2. Deletion Rights
You may request deletion of your account and data, subject to:
• Completion of active bookings
• Resolution of pending issues
• Legal retention requirements
• Financial record obligations

### 6.3. Communication Preferences
You can:
• Opt out of marketing emails
• Adjust notification settings
• Control data sharing preferences
• Manage cookie settings

### 6.4. Do Not Sell
We do not sell your personal information to third parties.

## 7. Data Retention
We retain your information:

• Account data: Duration of account plus 7 years
• Transaction records: 7 years for tax purposes
• Communication logs: 3 years
• Technical logs: 90 days
• Marketing data: Until you opt out

Retention periods may be extended for legal compliance or dispute resolution.

## 8. International Data Transfers
Your information may be transferred to and processed in:
• United States (primary servers)
• European Union (backup servers)
• Other countries where our service providers operate

We ensure appropriate safeguards for international transfers.

## 9. Children's Privacy
Our services are not intended for individuals under 18. We do not knowingly collect data from minors. If we discover such collection, we will delete it promptly.

## 10. Cookies and Tracking

### 10.1. Types of Cookies
• Essential cookies (required for functionality)
• Analytics cookies (usage tracking)
• Preference cookies (user settings)
• Marketing cookies (advertising)

### 10.2. Your Choices
You can control cookies through:
• Browser settings
• Cookie consent manager
• Opt-out tools

Disabling cookies may limit functionality.

## 11. Third-Party Links
Our platform may contain links to third-party websites. We are not responsible for their privacy practices. Please review their policies.

## 12. Changes to This Policy
We may update this Privacy Policy periodically. Material changes will be communicated via:
• Email notification
• In-app announcements
• Website banners

Continued use after changes constitutes acceptance.

## 13. Contact Information
For privacy-related questions or requests:

Email: privacy@bottlesup.com
Phone: +1-800-BOTTLES
Mail: Bottles Up Privacy Team
       123 Main Street
       New York, NY 10001

Data Protection Officer: dpo@bottlesup.com# Bottles Up Vendor - Deployment Guide

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