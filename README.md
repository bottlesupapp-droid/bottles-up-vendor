# Bottles Up Vendor App

A Flutter-based vendor management application for the Bottles Up platform with Supabase backend and Stripe integration.

## Prerequisites

- Flutter SDK (3.x or later)
- Dart SDK
- Supabase account and project
- Stripe account (for payment processing)

## Environment Setup

### 1. Configure Environment Variables

Copy the example environment file and fill in your values:

```bash
cp env.example.json env.json
```

Edit `env.json` with your actual Supabase credentials:

```json
{
  "SUPABASE_URL": "https://your-project-ref.supabase.co",
  "SUPABASE_ANON_KEY": "your-anon-key-here"
}
```

**Important**: Never commit `env.json` to version control. It's already in `.gitignore`.

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Generate Code (Riverpod, Freezed)

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Running the App

### Development

```bash
flutter run --dart-define-from-file=env.json
```

### Production Build

**Android APK**:
```bash
flutter build apk --release --dart-define-from-file=env.json
```

**Android App Bundle (for Play Store)**:
```bash
flutter build appbundle --release --dart-define-from-file=env.json
```

**iOS** (requires macOS with Xcode):
```bash
flutter build ios --release --dart-define-from-file=env.json
```

**Web**:
```bash
flutter build web --release --dart-define-from-file=env.json
```

## Supabase Edge Functions

The app uses 10 Supabase Edge Functions for Stripe integration and other backend operations:

1. `create-checkout` - Create Stripe checkout
2. `create-checkout-session` - Subscription checkout sessions
3. `create-payment-intent` - Payment intents
4. `stripe-webhook` - Handle Stripe webhooks
5. `send-email-notifications` - Email notifications
6. `create-portal-session` - Customer billing portal
7. `create-connect-account` - Vendor payout setup
8. `create-connect-login-link` - Stripe dashboard access
9. `create-payout` - Request payouts
10. `get-balance` - Check account balance

### Deploying Edge Functions

```bash
# Deploy all functions
./deploy-functions.sh

# Deploy a specific function
supabase functions deploy function-name

# Set required secrets
supabase secrets set STRIPE_SECRET_KEY=sk_live_...
```

See [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) for detailed deployment instructions.

## Project Structure

```
lib/
├── core/                    # Core app configuration
│   ├── config/             # Supabase, environment config
│   ├── router/             # GoRouter navigation
│   └── theme/              # App theming
├── features/               # Feature modules
│   ├── auth/               # Authentication
│   ├── dashboard/          # Analytics dashboard
│   ├── earnings/           # Earnings & payouts
│   ├── events/             # Event management
│   ├── profile/            # User profile
│   └── scanner/            # QR code scanning
├── shared/                 # Shared code
│   ├── models/             # Data models
│   ├── services/           # API services
│   └── widgets/            # Reusable widgets
└── main.dart               # App entry point
```

## Key Features

- **Event Management**: Create, edit, and manage events with ticketing
- **QR Code Check-in**: Scan and validate tickets
- **Subscription Management**: Stripe-powered subscription tiers
- **Vendor Payouts**: Stripe Connect integration for earnings
- **Analytics Dashboard**: Real-time event and revenue analytics
- **Multi-tier Ticketing**: Flexible ticket types and pricing
- **Guest List Management**: CSV upload and manual entry
- **Team Management**: Role-based access control

## Tech Stack

- **Framework**: Flutter 3.x
- **State Management**: Riverpod 2.x with code generation
- **Backend**: Supabase (PostgreSQL, Auth, Storage, Edge Functions)
- **Payments**: Stripe (Checkout, Connect, Webhooks)
- **Navigation**: GoRouter
- **UI**: Material Design 3 with custom dark theme

## Development Commands

```bash
# Run tests
flutter test

# Analyze code
flutter analyze

# Format code
dart format .

# Clean build
flutter clean && flutter pub get

# Watch for code generation changes
dart run build_runner watch
```

## Documentation

- [CLAUDE.md](CLAUDE.md) - Development guidelines and architecture
- [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) - Deployment instructions
- [FUNCTION_STATUS.md](FUNCTION_STATUS.md) - Edge functions inventory
- [supabase/functions/README.md](supabase/functions/README.md) - Edge functions API reference

## Support

For issues or questions, please check the documentation or contact the development team.
