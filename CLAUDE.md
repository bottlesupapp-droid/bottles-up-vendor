# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Essential Commands
- `flutter pub get` - Install dependencies after pubspec.yaml changes
- `flutter run` - Start development server (hot reload enabled)
- `flutter build apk` - Build Android APK for testing
- `flutter build appbundle` - Build Android App Bundle for Play Store
- `flutter build ios` - Build iOS app (requires macOS/Xcode)
- `flutter build web` - Build web application
- `flutter clean` - Clean build artifacts (run before `flutter pub get` when troubleshooting)

### Code Generation
- `dart run build_runner build` - Generate code (models, providers, etc.)
- `dart run build_runner build --delete-conflicting-outputs` - Force regenerate all generated files
- `dart run build_runner watch` - Watch for changes and auto-generate code

### Testing & Quality
- `flutter test` - Run unit tests
- `flutter analyze` - Static analysis (check for lint errors)
- `dart format .` - Format code according to Dart style guidelines

### Firebase & Deployment
- `firebase deploy --only hosting` - Deploy web version to Firebase Hosting
- `flutterfire configure` - Configure Firebase for Flutter (run when adding new Firebase services)

## Architecture Overview

### State Management
- **Riverpod 2.x** with code generation (`riverpod_generator`) for all state management
- Providers are defined using `@riverpod` annotations in `/providers/` directories
- Authentication state managed through `AuthProvider` in `features/auth/providers/`

### Navigation & Routing
- **GoRouter** with declarative routing configuration in `core/router/app_router.dart`
- Shell routing used for main navigation with persistent bottom navigation bar
- Custom page transitions (slide/fade) defined in router
- Auth guard redirects unauthenticated users to login

### Project Structure
```
lib/
├── core/                    # Core app configuration
│   ├── router/             # GoRouter configuration
│   ├── theme/              # App theming (dark theme with orange accents)
│   └── utils/              # Utility functions
├── features/               # Feature-based architecture
│   ├── auth/               # Authentication (login, register, forgot password)
│   ├── dashboard/          # Main dashboard with analytics
│   ├── clubs/              # Club management
│   ├── events/             # Event management, inventory, bookings
│   └── profile/            # User profile management
├── shared/                 # Shared components
│   ├── models/             # Data models (Freezed classes)
│   ├── services/           # Firebase and other services
│   └── widgets/            # Reusable widgets
└── main.dart               # App entry point
```

### Data Layer
- **Firebase** as backend (Firestore, Auth, Storage)
- **Freezed** for immutable data classes with JSON serialization
- Models in `shared/models/` with `.g.dart` and `.freezed.dart` generated files
- Firebase configuration in `firebase_options.dart` (auto-generated)

### UI/UX Architecture
- **Material Design 3** with custom dark theme
- **Flex Color Scheme** for consistent theming
- **Google Fonts** (Inter font family)
- Orange primary color (#FF6B35) with ultra-dark backgrounds
- Custom card decorations and zero elevations for flat design
- Reactive forms using `reactive_forms` package

### Key Features
- Vendor authentication system
- Dashboard with real-time analytics
- Event management with booking tracking
- Bottle inventory management
- Club/venue management
- Profile management with settings

## Firebase Integration

### Current Setup
- Project ID: `bottles-up-2d907` (production)
- Services: Authentication, Firestore, Storage
- Security rules defined in `firestore.rules`
- Indexes configured in `firestore.indexes.json`

### Collections Structure
- `vendors/` - Vendor user profiles
- `events/` - Event information and details
- `bookings/` - Customer booking records
- `inventory/` - Bottle inventory data

## Development Guidelines

### Code Generation Workflow
When modifying models or providers:
1. Make changes to the Dart files
2. Run `dart run build_runner build --delete-conflicting-outputs`
3. Commit both source and generated files

### State Management Pattern
- Use `@riverpod` annotation for providers
- Keep providers close to features (in feature's `providers/` folder)
- Use `AsyncValue<T>` for async data loading states
- Implement proper error handling in providers

### Navigation Pattern
- Use named routes defined in `AppRoutes` class
- Access router via `context.go()`, `context.push()`, etc.
- Pass parameters through route parameters or state objects
- Shell routing maintains bottom navigation across feature screens

### Firebase Development
- Use Firebase Local Emulator Suite for local development when needed
- All Firestore operations should handle offline scenarios
- Implement proper security rules before production deployment
- Use Firebase Analytics for tracking user engagement