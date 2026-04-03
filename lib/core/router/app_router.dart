import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Import screens (we'll create these next)
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/phone_login_screen.dart';
import '../../features/auth/screens/otp_verification_screen.dart';
import '../../features/auth/screens/database_setup_screen.dart';
import '../../features/auth/screens/debug_screen.dart';
import '../../features/auth/screens/role_selection_screen.dart';
import '../../features/auth/screens/onboarding/venue_onboarding_screen.dart';
import '../../features/auth/screens/onboarding/organizer_onboarding_screen.dart';
import '../../features/auth/screens/onboarding/promoter_onboarding_screen.dart';
import '../../features/auth/screens/onboarding/staff_onboarding_screen.dart';
import '../../features/auth/providers/supabase_auth_provider.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/clubs/screens/clubs_list_screen.dart';
import '../../features/clubs/screens/club_details_screen.dart';
import '../../features/clubs/screens/create_club_screen.dart';
import '../../features/events/screens/events_list_screen.dart';
import '../../features/events/screens/event_details_screen.dart';
import '../../features/events/screens/create_event_screen.dart';
import '../../features/events/screens/inventory_screen.dart';
import '../../features/events/screens/bookings_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/profile/screens/business_details_screen.dart';
import '../../features/profile/screens/security_screen.dart';
import '../../features/profile/screens/notifications_screen.dart';
import '../../features/profile/screens/help_center_screen.dart';
import '../../features/profile/screens/contact_support_screen.dart';
import '../../features/profile/screens/terms_of_service_screen.dart';
import '../../features/profile/screens/privacy_policy_screen.dart';
import '../../features/profile/screens/about_screen.dart';
import '../../features/venues/screens/venue_directory_screen.dart';
import '../../features/venues/screens/venue_detail_screen.dart';
import '../../features/venues/screens/venue_owner_requests_screen.dart';
import '../../features/venues/screens/venue_boost_screen.dart';
import '../../features/analytics/screens/analytics_dashboard_screen.dart';
import '../../features/scanner/screens/qr_scanner_screen.dart';
import '../../features/events/screens/guest_list_screen.dart';
import '../../features/events/screens/scheduled_releases_screen.dart';
import '../../shared/widgets/main_shell.dart';

// Route names
class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String phoneLogin = '/phone-login';
  static const String verifyOtp = '/verify-otp';
  static const String databaseSetup = '/database-setup';
  static const String debug = '/debug';
  static const String roleSelection = '/role-selection';
  static const String onboardingVenue = '/onboarding/venue';
  static const String onboardingOrganizer = '/onboarding/organizer';
  static const String onboardingPromoter = '/onboarding/promoter';
  static const String onboardingStaff = '/onboarding/staff';
  static const String dashboard = '/dashboard';
  static const String clubs = '/clubs';
  static const String clubDetails = '/clubs/:clubId';
  static const String createClub = '/clubs/create';
  static const String events = '/events';
  static const String eventDetails = '/events/:eventId';
  static const String createEvent = '/events/create';
  static const String inventory = '/inventory';
  static const String bookings = '/bookings';
  static const String analytics = '/analytics';
  static const String earnings = '/earnings';
  static const String profile = '/profile';
  static const String venues = '/venues';
  static const String venueDetail = '/venues/:venueId';
  static const String venueRequests = '/venue-requests';
  static const String venueBoost = '/venues/:venueId/boost';
  static const String qrScanner = '/events/:eventId/scanner';
  static const String guestList = '/events/:eventId/guests';
  static const String scheduledReleases = '/events/:eventId/releases';
}

// Custom page transitions using CupertinoPageRoute
class CupertinoTransitionPage extends CustomTransitionPage<void> {
  const CupertinoTransitionPage({
    required super.child,
    required super.name,
    super.arguments,
    super.restorationId,
    super.key,
  }) : super(
          transitionsBuilder: _cupertinoTransitionsBuilder,
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 400),
        );

  static Widget _cupertinoTransitionsBuilder(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return CupertinoPageTransition(
      primaryRouteAnimation: animation,
      secondaryRouteAnimation: secondaryAnimation,
      linearTransition: false,
      child: child,
    );
  }
}

// Router provider
final routerProvider = Provider<GoRouter>((ref) {
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  final vendorUser = ref.watch(currentVendorUserProvider);

  return GoRouter(
    initialLocation: AppRoutes.login,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = isAuthenticated;
      final currentPath = state.uri.path;

      // Define auth-related routes (no redirect needed)
      final isAuthRoute = currentPath == AppRoutes.login ||
                          currentPath == AppRoutes.register ||
                          currentPath == AppRoutes.forgotPassword ||
                          currentPath == AppRoutes.phoneLogin ||
                          currentPath == AppRoutes.verifyOtp ||
                          currentPath == AppRoutes.databaseSetup ||
                          currentPath == AppRoutes.debug ||
                          currentPath == AppRoutes.roleSelection;

      // Define onboarding routes
      final isOnboardingRoute = currentPath == AppRoutes.onboardingVenue ||
                                currentPath == AppRoutes.onboardingOrganizer ||
                                currentPath == AppRoutes.onboardingPromoter ||
                                currentPath == AppRoutes.onboardingStaff;

      // If not logged in and not on auth route, redirect to login
      if (!isLoggedIn && !isAuthRoute) {
        return AppRoutes.login;
      }

      // If logged in, check onboarding completion
      if (isLoggedIn && vendorUser != null) {
        // If onboarding not completed, redirect to role-specific onboarding
        if (!vendorUser.onboardingCompleted && !isOnboardingRoute) {
          switch (vendorUser.role) {
            case 'venue_owner':
              return AppRoutes.onboardingVenue;
            case 'organizer':
              return AppRoutes.onboardingOrganizer;
            case 'promoter':
              return AppRoutes.onboardingPromoter;
            case 'staff':
              return AppRoutes.onboardingStaff;
            default:
              // If role is unknown, default to organizer onboarding
              return AppRoutes.onboardingOrganizer;
          }
        }

        // If onboarding completed and on auth/onboarding route, redirect to dashboard
        if (vendorUser.onboardingCompleted && (isAuthRoute || isOnboardingRoute)) {
          return AppRoutes.dashboard;
        }
      }

      // No redirect needed
      return null;
    },
    routes: [
      // Auth routes (no shell)
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        pageBuilder: (context, state) => CupertinoTransitionPage(
          name: 'login',
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        pageBuilder: (context, state) => CupertinoTransitionPage(
          name: 'register',
          child: const RegisterScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: 'forgotPassword',
        pageBuilder: (context, state) => CupertinoTransitionPage(
          name: 'forgotPassword',
          child: const ForgotPasswordScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.phoneLogin,
        name: 'phoneLogin',
        pageBuilder: (context, state) => CupertinoTransitionPage(
          name: 'phoneLogin',
          child: const PhoneLoginScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.verifyOtp,
        name: 'verifyOtp',
        pageBuilder: (context, state) {
          final phoneNumber = state.extra as String;
          return CupertinoTransitionPage(
            name: 'verifyOtp',
            child: OtpVerificationScreen(phoneNumber: phoneNumber),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.databaseSetup,
        name: 'databaseSetup',
        pageBuilder: (context, state) => CupertinoTransitionPage(
          name: 'databaseSetup',
          child: const DatabaseSetupScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.debug,
        name: 'debug',
        pageBuilder: (context, state) => CupertinoTransitionPage(
          name: 'debug',
          child: const DebugScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.roleSelection,
        name: 'roleSelection',
        pageBuilder: (context, state) {
          final userData = state.extra as Map<String, String>;
          return CupertinoTransitionPage(
            name: 'roleSelection',
            child: RoleSelectionScreen(userData: userData),
          );
        },
      ),

      // Onboarding routes (no shell)
      GoRoute(
        path: AppRoutes.onboardingVenue,
        name: 'onboardingVenue',
        pageBuilder: (context, state) => CupertinoTransitionPage(
          name: 'onboardingVenue',
          child: const VenueOnboardingScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.onboardingOrganizer,
        name: 'onboardingOrganizer',
        pageBuilder: (context, state) => CupertinoTransitionPage(
          name: 'onboardingOrganizer',
          child: const OrganizerOnboardingScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.onboardingPromoter,
        name: 'onboardingPromoter',
        pageBuilder: (context, state) => CupertinoTransitionPage(
          name: 'onboardingPromoter',
          child: const PromoterOnboardingScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.onboardingStaff,
        name: 'onboardingStaff',
        pageBuilder: (context, state) => CupertinoTransitionPage(
          name: 'onboardingStaff',
          child: const StaffOnboardingScreen(),
        ),
      ),

      // Main shell with bottom navigation
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          // Dashboard
          GoRoute(
            path: AppRoutes.dashboard,
            name: 'dashboard',
            pageBuilder: (context, state) => CupertinoTransitionPage(
              name: 'dashboard',
              child: const DashboardScreen(),
            ),
          ),

          // Clubs
          GoRoute(
            path: AppRoutes.clubs,
            name: 'clubs',
            pageBuilder: (context, state) => CupertinoTransitionPage(
              name: 'clubs',
              child: const ClubsListScreen(),
            ),
            routes: [
              GoRoute(
                path: 'create',
                name: 'createClub',
                pageBuilder: (context, state) => CupertinoTransitionPage(
                  name: 'createClub',
                  child: const CreateClubScreen(),
                ),
              ),
              GoRoute(
                path: ':clubId',
                name: 'clubDetails',
                pageBuilder: (context, state) => CupertinoTransitionPage(
                  name: 'clubDetails',
                  child: ClubDetailsScreen(
                    clubId: state.pathParameters['clubId']!,
                  ),
                ),
              ),
            ],
          ),

          // Events
          GoRoute(
            path: AppRoutes.events,
            name: 'events',
            pageBuilder: (context, state) => CupertinoTransitionPage(
              name: 'events',
              child: const EventsListScreen(),
            ),
            routes: [
              GoRoute(
                path: 'create',
                name: 'createEvent',
                pageBuilder: (context, state) => CupertinoTransitionPage(
                  name: 'createEvent',
                  child: const CreateEventScreen(),
                ),
              ),
              GoRoute(
                path: ':eventId',
                name: 'eventDetails',
                pageBuilder: (context, state) => CupertinoTransitionPage(
                  name: 'eventDetails',
                  child: EventDetailsScreen(
                    eventId: state.pathParameters['eventId']!,
                  ),
                ),
                routes: [
                  GoRoute(
                    path: 'scanner',
                    name: 'qrScanner',
                    pageBuilder: (context, state) => CupertinoTransitionPage(
                      name: 'qrScanner',
                      child: QRScannerScreen(
                        eventId: state.pathParameters['eventId']!,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'guests',
                    name: 'guestList',
                    pageBuilder: (context, state) => CupertinoTransitionPage(
                      name: 'guestList',
                      child: GuestListScreen(
                        eventId: state.pathParameters['eventId']!,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'releases',
                    name: 'scheduledReleases',
                    pageBuilder: (context, state) => CupertinoTransitionPage(
                      name: 'scheduledReleases',
                      child: ScheduledReleasesScreen(
                        eventId: state.pathParameters['eventId']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Inventory
          GoRoute(
            path: AppRoutes.inventory,
            name: 'inventory',
            pageBuilder: (context, state) => CupertinoTransitionPage(
              name: 'inventory',
              child: const InventoryScreen(),
            ),
          ),

          // Bookings
          GoRoute(
            path: AppRoutes.bookings,
            name: 'bookings',
            pageBuilder: (context, state) => CupertinoTransitionPage(
              name: 'bookings',
              child: const BookingsScreen(),
            ),
          ),

          // Analytics
          GoRoute(
            path: AppRoutes.analytics,
            name: 'analytics',
            pageBuilder: (context, state) => CupertinoTransitionPage(
              name: 'analytics',
              child: const AnalyticsDashboardScreen(),
            ),
          ),

          // Earnings (placeholder)
          GoRoute(
            path: AppRoutes.earnings,
            name: 'earnings',
            pageBuilder: (context, state) => CupertinoTransitionPage(
              name: 'earnings',
              child: const Scaffold(
                appBar: null,
                body: Center(
                  child: Text('Earnings - Coming Soon'),
                ),
              ),
            ),
          ),

          // Profile
          GoRoute(
            path: AppRoutes.profile,
            name: 'profile',
            pageBuilder: (context, state) => CupertinoTransitionPage(
              name: 'profile',
              child: const ProfileScreen(),
            ),
            routes: [
              GoRoute(
                path: 'edit',
                name: 'editProfile',
                pageBuilder: (context, state) => CupertinoTransitionPage(
                  name: 'editProfile',
                  child: const EditProfileScreen(),
                ),
              ),
              GoRoute(
                path: 'business',
                name: 'businessDetails',
                pageBuilder: (context, state) => CupertinoTransitionPage(
                  name: 'businessDetails',
                  child: const BusinessDetailsScreen(),
                ),
              ),
              GoRoute(
                path: 'security',
                name: 'security',
                pageBuilder: (context, state) => CupertinoTransitionPage(
                  name: 'security',
                  child: const SecurityScreen(),
                ),
              ),
              GoRoute(
                path: 'notifications',
                name: 'notifications',
                pageBuilder: (context, state) => CupertinoTransitionPage(
                  name: 'notifications',
                  child: const NotificationsScreen(),
                ),
              ),
            ],
          ),

          // Venues (for organizers to browse and send proposals)
          GoRoute(
            path: AppRoutes.venues,
            name: 'venues',
            pageBuilder: (context, state) => CupertinoTransitionPage(
              name: 'venues',
              child: const VenueDirectoryScreen(),
            ),
            routes: [
              GoRoute(
                path: ':venueId',
                name: 'venueDetail',
                pageBuilder: (context, state) {
                  // Venue object should be passed as extra
                  final venue = state.extra;
                  return CupertinoTransitionPage(
                    name: 'venueDetail',
                    child: VenueDetailScreen(
                      venue: venue as dynamic,
                    ),
                  );
                },
                routes: [
                  GoRoute(
                    path: 'boost',
                    name: 'venueBoost',
                    pageBuilder: (context, state) => CupertinoTransitionPage(
                      name: 'venueBoost',
                      child: VenueBoostScreen(
                        venueId: state.pathParameters['venueId']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Venue Requests (for venue owners to manage requests)
          GoRoute(
            path: AppRoutes.venueRequests,
            name: 'venueRequests',
            pageBuilder: (context, state) => CupertinoTransitionPage(
              name: 'venueRequests',
              child: const VenueOwnerRequestsScreen(),
            ),
          ),
        ],
      ),

      // Support routes (global - not inside shell)
      GoRoute(
        path: '/support/help',
        name: 'helpCenter',
        pageBuilder: (context, state) => CupertinoTransitionPage(
          name: 'helpCenter',
          child: const HelpCenterScreen(),
        ),
      ),
      GoRoute(
        path: '/support/contact',
        name: 'contactSupport',
        pageBuilder: (context, state) => CupertinoTransitionPage(
          name: 'contactSupport',
          child: const ContactSupportScreen(),
        ),
      ),

      // Legal routes (global - not inside shell)
      GoRoute(
        path: '/legal/terms',
        name: 'termsOfService',
        pageBuilder: (context, state) => CupertinoTransitionPage(
          name: 'termsOfService',
          child: const TermsOfServiceScreen(),
        ),
      ),
      GoRoute(
        path: '/legal/privacy',
        name: 'privacyPolicy',
        pageBuilder: (context, state) => CupertinoTransitionPage(
          name: 'privacyPolicy',
          child: const PrivacyPolicyScreen(),
        ),
      ),

      // About route (global - not inside shell)
      GoRoute(
        path: '/about',
        name: 'about',
        pageBuilder: (context, state) => CupertinoTransitionPage(
          name: 'about',
          child: const AboutScreen(),
        ),
      ),
    ],
  );
});

// Router helper extensions
extension GoRouterExtensions on GoRouter {
  void pushAndClearStack(String location) {
    while (canPop()) {
      pop();
    }
    pushReplacement(location);
  }
} 